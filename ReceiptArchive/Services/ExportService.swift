import Foundation
import UIKit

enum ExportError: LocalizedError {
    case couldNotCreateFile
    var errorDescription: String? { "The export file could not be created." }
}

@MainActor
final class ExportService {
    func create(format: ExportFormat, receipts: [Receipt], title: String) throws -> URL {
        let safeTitle = title.replacingOccurrences(of: #"[^A-Za-z0-9_-]"#, with: "-", options: .regularExpression)
        let folder = FileManager.default.temporaryDirectory.appending(path: "ReceiptArchive-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        switch format {
        case .csv:
            let url = folder.appending(path: "\(safeTitle).csv")
            try csv(receipts).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .pdf:
            let url = folder.appending(path: "\(safeTitle).pdf")
            try pdf(receipts: receipts, title: title).write(to: url)
            return url
        case .xlsx:
            let url = folder.appending(path: "\(safeTitle).xlsx")
            try workbook(receipts: receipts).write(to: url)
            return url
        case .docx:
            let url = folder.appending(path: "\(safeTitle).docx")
            try wordReport(receipts: receipts, title: title).write(to: url)
            return url
        case .images:
            let url = folder.appending(path: "\(safeTitle)-JPGs.zip")
            try imageBundle(receipts: receipts).write(to: url)
            return url
        }
    }

    private func csv(_ receipts: [Receipt]) -> String {
        var rows = ["Date,Merchant,Matter,Category,Currency,Subtotal,Tax,Total,Review Status,OCR Confidence,Validation Notes,Revision Count,Last Revised,Notes"]
        rows += receipts.map {
            [Self.iso.string(from: $0.transactionDate), $0.merchant, $0.matter?.name ?? "", $0.category.rawValue, $0.currencyCode, Self.number($0.subtotal), Self.number($0.tax), Self.number($0.total), $0.reviewStatus.title, String(format: "%.0f%%", $0.ocrConfidence * 100), $0.validationNotes, "\($0.revisions.count)", $0.revisions.map(\.changedAt).max().map(Self.iso.string) ?? "", $0.notes]
                .map(Self.csvEscape).joined(separator: ",")
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    private func pdf(receipts: [Receipt], title: String) throws -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var y: CGFloat = 42
            func newPage() {
                context.beginPage()
                y = 42
            }
            func draw(_ text: String, font: UIFont, color: UIColor = .label, indent: CGFloat = 0) {
                let rect = CGRect(x: 42 + indent, y: y, width: page.width - 84 - indent, height: 80)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let height = (text as NSString).boundingRect(with: rect.size, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil).height
                if y + height > page.height - 45 { newPage() }
                (text as NSString).draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: height + 2), withAttributes: attributes)
                y += height + 8
            }
            newPage()
            draw(title, font: .boldSystemFont(ofSize: 25))
            draw("Expense report • \(Date.now.formatted(date: .long, time: .shortened))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 8
            for (currency, rows) in Dictionary(grouping: receipts, by: \Receipt.currencyCode).sorted(by: { $0.key < $1.key }) {
                let total = rows.reduce(Decimal.zero) { $0 + $1.total }
                draw("\(currency) total: \(total.formatted(.currency(code: currency)))", font: .boldSystemFont(ofSize: 16))
            }
            y += 8
            draw("By category", font: .boldSystemFont(ofSize: 15))
            for row in summaryRows(receipts).dropFirst().filter({ $0.first == "Category" }) {
                draw(row.dropFirst().joined(separator: " • "), font: .systemFont(ofSize: 11))
            }
            draw("By date", font: .boldSystemFont(ofSize: 15))
            for row in summaryRows(receipts).dropFirst().filter({ $0.first == "Date" }) {
                draw(row.dropFirst().joined(separator: " • "), font: .systemFont(ofSize: 11))
            }
            y += 12
            for receipt in receipts {
                draw("\(receipt.transactionDate.formatted(date: .abbreviated, time: .omitted))  \(receipt.merchant)", font: .boldSystemFont(ofSize: 13))
                draw("\(receipt.category.rawValue) • \(receipt.matter?.name ?? "Unfiled") • \(receipt.total.formatted(.currency(code: receipt.currencyCode)))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
                draw("Evidence: \(receipt.reviewStatus.title) • OCR \(String(format: "%.0f%%", receipt.ocrConfidence * 100))", font: .systemFont(ofSize: 10), color: receipt.reviewStatus == .verified ? .systemGreen : .systemOrange)
                if !receipt.revisions.isEmpty { draw("Audit trail: \(receipt.revisions.count) field change\(receipt.revisions.count == 1 ? "" : "s")", font: .systemFont(ofSize: 10), color: .secondaryLabel) }
                if let pageData = receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex }).first?.imageData,
                   let image = UIImage(data: pageData) {
                    let maxHeight: CGFloat = 250
                    let ratio = min((page.width - 100) / image.size.width, maxHeight / image.size.height)
                    let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    if y + size.height > page.height - 45 { newPage() }
                    image.draw(in: CGRect(x: 50, y: y, width: size.width, height: size.height))
                    y += size.height + 16
                }
            }
        }
    }

    private func workbook(receipts: [Receipt]) throws -> Data {
        let headers = ["Date", "Merchant", "Matter", "Category", "Currency", "Subtotal", "Tax", "Total", "Review Status", "OCR Confidence", "Validation Notes", "Revision Count", "Last Revised", "Notes"]
        var rows = [headers]
        rows += receipts.map { [Self.iso.string(from: $0.transactionDate), $0.merchant, $0.matter?.name ?? "", $0.category.rawValue, $0.currencyCode, Self.number($0.subtotal), Self.number($0.tax), Self.number($0.total), $0.reviewStatus.title, String(format: "%.0f%%", $0.ocrConfidence * 100), $0.validationNotes, "\($0.revisions.count)", $0.revisions.map(\.changedAt).max().map(Self.iso.string) ?? "", $0.notes] }
        func worksheet(_ sourceRows: [[String]]) -> String {
            let body = sourceRows.enumerated().map { rowIndex, columns in
            let cells = columns.enumerated().map { columnIndex, value in
                let ref = "\(Self.columnName(columnIndex + 1))\(rowIndex + 1)"
                return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(Self.xml(value))</t></is></c>"
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cells)</row>"
            }.joined()
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>\(body)</sheetData></worksheet>"
        }
        let files: [String: Data] = [
            "[Content_Types].xml": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/><Override PartName=\"/xl/worksheets/sheet2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>"),
            "_rels/.rels": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"),
            "xl/workbook.xml": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Expenses\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"Summary\" sheetId=\"2\" r:id=\"rId2\"/></sheets></workbook>"),
            "xl/_rels/workbook.xml.rels": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet2.xml\"/></Relationships>"),
            "xl/worksheets/sheet1.xml": Self.data(worksheet(rows)),
            "xl/worksheets/sheet2.xml": Self.data(worksheet(summaryRows(receipts)))
        ]
        return ZipStoreArchive(files: files).data()
    }

    private func wordReport(receipts: [Receipt], title: String) throws -> Data {
        let rows = receipts.map { receipt in
            "<w:tr><w:tc><w:p><w:r><w:t>\(Self.xml(Self.iso.string(from: receipt.transactionDate)))</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>\(Self.xml(receipt.merchant))</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>\(Self.xml(receipt.category.rawValue))</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>\(Self.xml(receipt.currencyCode + " " + Self.number(receipt.total)))</w:t></w:r></w:p></w:tc></w:tr>"
        }.joined()
        let summary = summaryRows(receipts).dropFirst().map { "<w:p><w:r><w:t>\(Self.xml($0.joined(separator: " • ")))</w:t></w:r></w:p>" }.joined()
        let document = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:rPr><w:b/><w:sz w:val=\"36\"/></w:rPr><w:t>\(Self.xml(title))</w:t></w:r></w:p><w:p><w:r><w:t>Expense summary generated \(Self.xml(Date.now.formatted()))</w:t></w:r></w:p>\(summary)<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Date</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Merchant</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Category</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Total</w:t></w:r></w:p></w:tc></w:tr>\(rows)</w:tbl></w:body></w:document>"
        let files: [String: Data] = [
            "[Content_Types].xml": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>"),
            "_rels/.rels": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"),
            "word/document.xml": Self.data(document)
        ]
        return ZipStoreArchive(files: files).data()
    }

    private func imageBundle(receipts: [Receipt]) throws -> Data {
        var files: [String: Data] = ["expenses.csv": Self.data(csv(receipts))]
        for (receiptIndex, receipt) in receipts.enumerated() {
            for page in receipt.pages {
                let merchant = receipt.merchant.replacingOccurrences(of: #"[^A-Za-z0-9_-]"#, with: "-", options: .regularExpression)
                files[String(format: "%03d-%@-page-%02d.jpg", receiptIndex + 1, merchant, page.pageIndex + 1)] = page.imageData
            }
        }
        return ZipStoreArchive(files: files).data()
    }

    private func summaryRows(_ receipts: [Receipt]) -> [[String]] {
        var rows = [["Breakdown", "Group", "Currency", "Total"]]
        for (currency, values) in Dictionary(grouping: receipts, by: \Receipt.currencyCode).sorted(by: { $0.key < $1.key }) {
            rows.append(["Currency", currency, currency, Self.number(values.reduce(Decimal.zero) { $0 + $1.total })])
        }
        for category in ExpenseCategory.allCases {
            for (currency, values) in Dictionary(grouping: receipts.filter { $0.category == category }, by: \Receipt.currencyCode).sorted(by: { $0.key < $1.key }) {
                rows.append(["Category", category.rawValue, currency, Self.number(values.reduce(Decimal.zero) { $0 + $1.total })])
            }
        }
        let dates = Dictionary(grouping: receipts, by: { Calendar.current.startOfDay(for: $0.transactionDate) })
        for (date, dateRows) in dates.sorted(by: { $0.key < $1.key }) {
            for (currency, values) in Dictionary(grouping: dateRows, by: \Receipt.currencyCode).sorted(by: { $0.key < $1.key }) {
                rows.append(["Date", Self.iso.string(from: date), currency, Self.number(values.reduce(Decimal.zero) { $0 + $1.total })])
            }
        }
        return rows
    }

    private static let iso: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "en_US_POSIX"); value.dateFormat = "yyyy-MM-dd"; return value
    }()
    private static func number(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
    private static func csvEscape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    private static func xml(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }
    private static func data(_ value: String) -> Data { Data(value.utf8) }
    private static func columnName(_ index: Int) -> String { index <= 26 ? String(UnicodeScalar(64 + index)!) : "A" }
}

private struct ZipStoreArchive {
    let files: [String: Data]

    func data() -> Data {
        var output = Data()
        var central = Data()
        var offset: UInt32 = 0
        for (name, contents) in files.sorted(by: { $0.key < $1.key }) {
            let nameData = Data(name.utf8)
            let crc = CRC32.checksum(contents)
            var local = Data()
            local.appendLE(UInt32(0x04034b50)); local.appendLE(UInt16(20)); local.appendLE(UInt16(0)); local.appendLE(UInt16(0))
            local.appendLE(UInt16(0)); local.appendLE(UInt16(0x0021)); local.appendLE(crc); local.appendLE(UInt32(contents.count)); local.appendLE(UInt32(contents.count))
            local.appendLE(UInt16(nameData.count)); local.appendLE(UInt16(0)); local.append(nameData); local.append(contents)
            output.append(local)

            central.appendLE(UInt32(0x02014b50)); central.appendLE(UInt16(20)); central.appendLE(UInt16(20)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0x0021)); central.appendLE(crc); central.appendLE(UInt32(contents.count)); central.appendLE(UInt32(contents.count))
            central.appendLE(UInt16(nameData.count)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt32(0)); central.appendLE(offset); central.append(nameData)
            offset += UInt32(local.count)
        }
        let centralOffset = UInt32(output.count)
        output.append(central)
        output.appendLE(UInt32(0x06054b50)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0)); output.appendLE(UInt16(files.count)); output.appendLE(UInt16(files.count)); output.appendLE(UInt32(central.count)); output.appendLE(centralOffset); output.appendLE(UInt16(0))
        return output
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data { crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xff)] }
        return crc ^ 0xffffffff
    }
    static let table: [UInt32] = (0..<256).map { value in
        var c = UInt32(value)
        for _ in 0..<8 { c = (c & 1) == 1 ? 0xedb88320 ^ (c >> 1) : c >> 1 }
        return c
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
