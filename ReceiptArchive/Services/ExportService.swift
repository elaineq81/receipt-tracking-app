import CryptoKit
import Foundation
import UIKit

enum ExportError: LocalizedError {
    case couldNotCreateFile
    case noReceiptImage

    var errorDescription: String? {
        switch self {
        case .couldNotCreateFile: "The export file could not be created."
        case .noReceiptImage: "This receipt does not contain an image to share."
        }
    }
}

final class ExportService: @unchecked Sendable {
    @MainActor
    func create(format: ExportFormat, receipts: [Receipt], title: String) async throws -> URL {
        let snapshots = receipts.map(ExportReceiptSnapshot.init)
        return try await Task.detached(priority: .userInitiated) {
            try self.create(format: format, receipts: snapshots, title: title)
        }.value
    }

    private func create(format: ExportFormat, receipts: [ExportReceiptSnapshot], title: String) throws -> URL {
        let safeTitle = title.replacingOccurrences(of: #"[^A-Za-z0-9_-]"#, with: "-", options: .regularExpression)
        let folder = FileManager.default.temporaryDirectory.appending(path: "ReceiptSure-\(UUID().uuidString)", directoryHint: .isDirectory)
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
        case .proof:
            let url = folder.appending(path: "\(safeTitle)-ReceiptSure-Proof-Pack.zip")
            try proofPack(receipts: receipts, title: title).write(to: url)
            return url
        }
    }

    @MainActor
    func createReceiptImageFiles(receipt: Receipt) async throws -> [URL] {
        let snapshot = ExportReceiptSnapshot(receipt)
        return try await Task.detached(priority: .userInitiated) {
            try self.createReceiptImageFiles(receipt: snapshot)
        }.value
    }

    private func createReceiptImageFiles(receipt: ExportReceiptSnapshot) throws -> [URL] {
        let pages = receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex })
        guard !pages.isEmpty else { throw ExportError.noReceiptImage }

        let folder = FileManager.default.temporaryDirectory
            .appending(path: "ReceiptSure-Share-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let merchant = safeFilename(receipt.merchant.isEmpty ? "Receipt" : receipt.merchant)
        let date = Self.iso.string(from: receipt.transactionDate)
        return try pages.map { page in
            let url = folder.appending(path: "\(date)-\(merchant)-page-\(page.pageIndex + 1).jpg")
            try page.imageData.write(to: url, options: .atomic)
            return url
        }
    }

    private func csv(_ receipts: [ExportReceiptSnapshot]) -> String {
        var rows = ["Date,Merchant,Matter,Category,Payment Method,Reimbursement,Client or Cost Centre,Tags,Currency,Subtotal,Tax Label,Tax,Tip,Discount,Total,Reporting Currency,Exchange Rate,Rate Date,Rate Source,Reporting Total,Review Status,OCR Confidence,Validation Notes,Revision Count,Last Revised,Notes,Line Items,Line Item Total,Minimum Key Field Confidence,Original Evidence Seal,Current Evidence Seal,Evidence Sealed At"]
        rows += receipts.map {
            [Self.iso.string(from: $0.transactionDate), $0.merchant, $0.matterName ?? "", $0.category.rawValue, $0.paymentMethod.rawValue, $0.reimbursementStatus.rawValue, $0.clientOrCostCentre, $0.tagsRaw, $0.currencyCode, Self.number($0.subtotal), $0.taxLabel, Self.number($0.tax), Self.number($0.tip), Self.number($0.discount), Self.number($0.total), $0.reportingCurrencyCode, Self.number($0.exchangeRate), $0.exchangeRateDate.map(Self.iso.string) ?? "", $0.exchangeRateSource, $0.reportingTotal.map(Self.number) ?? "", $0.reviewStatus.title, String(format: "%.0f%%", $0.ocrConfidence * 100), $0.validationNotes, "\($0.revisionDates.count)", $0.revisionDates.max().map(Self.iso.string) ?? "", $0.notes, Self.lineItemsText($0), Self.number($0.lineItemTotal), String(format: "%.0f%%", $0.fieldConfidence.minimumKeyField * 100), $0.originalEvidenceDigest, $0.currentEvidenceDigest, $0.evidenceSealedAt.map(Self.iso.string) ?? ""]
                .map(Self.csvEscape).joined(separator: ",")
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    private func pdf(receipts: [ExportReceiptSnapshot], title: String) throws -> Data {
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
            draw("Evidence pack • \(Date.now.formatted(date: .long, time: .shortened))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            if let first = receipts.map(\.transactionDate).min(), let last = receipts.map(\.transactionDate).max() {
                draw("Period: \(first.formatted(date: .long, time: .omitted)) – \(last.formatted(date: .long, time: .omitted))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            }
            let verified = receipts.filter { $0.reviewStatus == .verified }.count
            let reconciliationIssues = receipts.filter { abs(NSDecimalNumber(decimal: $0.reconciliationDifference).doubleValue) > 0.02 }.count
            let incompleteRates = receipts.filter {
                let any = !$0.reportingCurrencyCode.isEmpty || $0.exchangeRate > 0 || $0.exchangeRateDate != nil || !$0.exchangeRateSource.isEmpty
                return any && !$0.hasCompleteConversion
            }.count
            draw("Readiness", font: .boldSystemFont(ofSize: 16))
            draw("\(receipts.count) receipts • \(verified) verified • \(receipts.count - verified) need review", font: .systemFont(ofSize: 11))
            draw("\(reconciliationIssues) figure exceptions • \(incompleteRates) incomplete conversions", font: .systemFont(ofSize: 11), color: reconciliationIssues + incompleteRates == 0 ? .systemGreen : .systemOrange)
            y += 8
            for (currency, rows) in Dictionary(grouping: receipts, by: \.currencyCode).sorted(by: { $0.key < $1.key }) {
                let total = rows.reduce(Decimal.zero) { $0 + $1.total }
                draw("\(currency) total: \(total.formatted(.currency(code: currency)))", font: .boldSystemFont(ofSize: 16))
            }
            for (currency, rows) in Dictionary(grouping: receipts.filter(\.hasCompleteConversion), by: \.reportingCurrencyCode).sorted(by: { $0.key < $1.key }) {
                let total = rows.compactMap(\.reportingTotal).reduce(Decimal.zero, +)
                draw("Reporting total: \(total.formatted(.currency(code: currency)))", font: .boldSystemFont(ofSize: 16), color: .systemTeal)
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
            newPage()
            draw("Receipt evidence appendix", font: .boldSystemFont(ofSize: 22))
            for receipt in receipts {
                draw("\(receipt.transactionDate.formatted(date: .abbreviated, time: .omitted))  \(receipt.merchant)", font: .boldSystemFont(ofSize: 13))
                draw("\(receipt.category.rawValue) • \(receipt.matterName ?? "Unfiled") • \(receipt.total.formatted(.currency(code: receipt.currencyCode)))", font: .systemFont(ofSize: 11), color: .secondaryLabel)
                draw("\(receipt.paymentMethod.rawValue) • \(receipt.reimbursementStatus.rawValue)\(receipt.clientOrCostCentre.isEmpty ? "" : " • " + receipt.clientOrCostCentre)", font: .systemFont(ofSize: 10), color: .secondaryLabel)
                draw("Subtotal \(receipt.subtotal.formatted(.currency(code: receipt.currencyCode))) • \(receipt.taxLabel) \(receipt.tax.formatted(.currency(code: receipt.currencyCode))) • Tip \(receipt.tip.formatted(.currency(code: receipt.currencyCode))) • Discount \(receipt.discount.formatted(.currency(code: receipt.currencyCode)))", font: .systemFont(ofSize: 9), color: .secondaryLabel)
                if let reportingTotal = receipt.reportingTotal {
                    draw("Converted: \(reportingTotal.formatted(.currency(code: receipt.reportingCurrencyCode))) at \(Self.number(receipt.exchangeRate)) • \(receipt.exchangeRateSource) • \(receipt.exchangeRateDate?.formatted(date: .abbreviated, time: .omitted) ?? "")", font: .systemFont(ofSize: 9), color: .secondaryLabel)
                }
                draw("Evidence: \(receipt.reviewStatus.title) • OCR \(String(format: "%.0f%%", receipt.ocrConfidence * 100))", font: .systemFont(ofSize: 10), color: receipt.reviewStatus == .verified ? .systemGreen : .systemOrange)
                if !receipt.currentEvidenceDigest.isEmpty {
                    draw("Integrity seal: \(String(receipt.currentEvidenceDigest.prefix(16)).uppercased()) • key-field floor \(String(format: "%.0f%%", receipt.fieldConfidence.minimumKeyField * 100))", font: .systemFont(ofSize: 9), color: .secondaryLabel)
                }
                if !receipt.lineItems.isEmpty {
                    draw("Line items", font: .boldSystemFont(ofSize: 10))
                    for item in receipt.lineItems {
                        draw("\(item.description) • \(Self.number(item.quantity)) × \(item.unitPrice.formatted(.currency(code: receipt.currencyCode))) • \(item.total.formatted(.currency(code: receipt.currencyCode)))", font: .systemFont(ofSize: 9), color: .secondaryLabel, indent: 10)
                    }
                }
                if !receipt.revisionDates.isEmpty { draw("Audit trail: \(receipt.revisionDates.count) field change\(receipt.revisionDates.count == 1 ? "" : "s")", font: .systemFont(ofSize: 10), color: .secondaryLabel) }
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

    private func workbook(receipts: [ExportReceiptSnapshot]) throws -> Data {
        let headers = ["Date", "Merchant", "Matter", "Category", "Payment Method", "Reimbursement", "Client or Cost Centre", "Tags", "Currency", "Subtotal", "Tax Label", "Tax", "Tip", "Discount", "Total", "Reporting Currency", "Exchange Rate", "Rate Date", "Rate Source", "Reporting Total", "Review Status", "OCR Confidence", "Validation Notes", "Revision Count", "Last Revised", "Notes", "Line Items", "Line Item Total", "Minimum Key Field Confidence", "Original Evidence Seal", "Current Evidence Seal", "Evidence Sealed At"]
        var rows = [headers]
        rows += receipts.map { [Self.iso.string(from: $0.transactionDate), $0.merchant, $0.matterName ?? "", $0.category.rawValue, $0.paymentMethod.rawValue, $0.reimbursementStatus.rawValue, $0.clientOrCostCentre, $0.tagsRaw, $0.currencyCode, Self.number($0.subtotal), $0.taxLabel, Self.number($0.tax), Self.number($0.tip), Self.number($0.discount), Self.number($0.total), $0.reportingCurrencyCode, Self.number($0.exchangeRate), $0.exchangeRateDate.map(Self.iso.string) ?? "", $0.exchangeRateSource, $0.reportingTotal.map(Self.number) ?? "", $0.reviewStatus.title, String(format: "%.0f%%", $0.ocrConfidence * 100), $0.validationNotes, "\($0.revisionDates.count)", $0.revisionDates.max().map(Self.iso.string) ?? "", $0.notes, Self.lineItemsText($0), Self.number($0.lineItemTotal), String(format: "%.0f%%", $0.fieldConfidence.minimumKeyField * 100), $0.originalEvidenceDigest, $0.currentEvidenceDigest, $0.evidenceSealedAt.map(Self.iso.string) ?? ""] }
        func worksheet(_ sourceRows: [[String]]) -> String {
            let body = sourceRows.enumerated().map { rowIndex, columns in
            let cells = columns.enumerated().map { columnIndex, value in
                let ref = "\(SpreadsheetColumnReference.name(for: columnIndex + 1))\(rowIndex + 1)"
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

    private func wordReport(receipts: [ExportReceiptSnapshot], title: String) throws -> Data {
        let rows = receipts.map { receipt in
            "<w:tr><w:tc><w:p><w:r><w:t>\(Self.xml(Self.iso.string(from: receipt.transactionDate)))</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>\(Self.xml(receipt.merchant))</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>\(Self.xml(receipt.category.rawValue + " • " + receipt.paymentMethod.rawValue + " • " + receipt.reimbursementStatus.rawValue))</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>\(Self.xml(receipt.currencyCode + " " + Self.number(receipt.total)))</w:t></w:r></w:p></w:tc></w:tr>"
        }.joined()
        let summary = summaryRows(receipts).dropFirst().map { "<w:p><w:r><w:t>\(Self.xml($0.joined(separator: " • ")))</w:t></w:r></w:p>" }.joined()
        let evidence = receipts.map { receipt in
            let seal = receipt.currentEvidenceDigest.isEmpty ? "Not sealed" : String(receipt.currentEvidenceDigest.prefix(16)).uppercased()
            let items = receipt.lineItems.isEmpty ? "No line items" : Self.lineItemsText(receipt)
            let confidence = String(format: "%.0f%%", receipt.fieldConfidence.minimumKeyField * 100)
            let sealLine = "Evidence seal: \(seal) • Key-field floor: \(confidence)"
            return "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>\(Self.xml(receipt.merchant))</w:t></w:r></w:p><w:p><w:r><w:t>\(Self.xml(sealLine))</w:t></w:r></w:p><w:p><w:r><w:t>\(Self.xml(items))</w:t></w:r></w:p>"
        }.joined()
        let document = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:rPr><w:b/><w:sz w:val=\"36\"/></w:rPr><w:t>\(Self.xml(title))</w:t></w:r></w:p><w:p><w:r><w:t>Expense summary generated \(Self.xml(Date.now.formatted()))</w:t></w:r></w:p>\(summary)<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Date</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Merchant</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Category</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Total</w:t></w:r></w:p></w:tc></w:tr>\(rows)</w:tbl><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Evidence and line items</w:t></w:r></w:p>\(evidence)</w:body></w:document>"
        let files: [String: Data] = [
            "[Content_Types].xml": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>"),
            "_rels/.rels": Self.data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"),
            "word/document.xml": Self.data(document)
        ]
        return ZipStoreArchive(files: files).data()
    }

    private func imageBundle(receipts: [ExportReceiptSnapshot]) throws -> Data {
        var files: [String: Data] = ["expenses.csv": Self.data(csv(receipts))]
        for (receiptIndex, receipt) in receipts.enumerated() {
            for page in receipt.pages {
                let merchant = receipt.merchant.replacingOccurrences(of: #"[^A-Za-z0-9_-]"#, with: "-", options: .regularExpression)
                files[String(format: "%03d-%@-page-%02d.jpg", receiptIndex + 1, merchant, page.pageIndex + 1)] = page.imageData
            }
        }
        return ZipStoreArchive(files: files).data()
    }

    private func proofPack(receipts: [ExportReceiptSnapshot], title: String) throws -> Data {
        var files: [String: Data] = [
            "README.txt": Self.data(
                """
                ReceiptSure Proof Pack

                This archive preserves the selected receipt records, images, revision history, and a SHA-256 manifest.
                The manifest verifies that included files have not changed since this pack was generated. It does not certify the commercial, legal, or tax validity of an expense.
                """
            ),
            "expenses.csv": Self.data(csv(receipts)),
            "summary.pdf": try pdf(receipts: receipts, title: title)
        ]

        let auditRecords = receipts.map(ProofReceiptRecord.init)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        files["audit/receipt-records.json"] = try encoder.encode(auditRecords)

        for (receiptIndex, receipt) in receipts.enumerated() {
            let merchant = safeFilename(receipt.merchant.isEmpty ? "Receipt" : receipt.merchant)
            let folder = String(format: "receipts/%03d-%@-%@", receiptIndex + 1, Self.iso.string(from: receipt.transactionDate), merchant)
            for page in receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
                let pageNumber = page.pageIndex + 1
                files[String(format: "%@/current-page-%02d.jpg", folder, pageNumber)] = page.imageData
                if let original = page.originalImageData {
                    files[String(format: "%@/original-page-%02d.jpg", folder, pageNumber)] = original
                }
            }
        }

        files["manifest.json"] = try ProofPackManifestBuilder.manifestData(for: files, title: title)
        return ZipStoreArchive(files: files).data()
    }

    private func summaryRows(_ receipts: [ExportReceiptSnapshot]) -> [[String]] {
        var rows = [["Breakdown", "Group", "Currency", "Total"]]
        for (currency, values) in Dictionary(grouping: receipts, by: \.currencyCode).sorted(by: { $0.key < $1.key }) {
            rows.append(["Currency", currency, currency, Self.number(values.reduce(Decimal.zero) { $0 + $1.total })])
        }
        for (currency, values) in Dictionary(grouping: receipts.filter(\.hasCompleteConversion), by: \.reportingCurrencyCode).sorted(by: { $0.key < $1.key }) {
            rows.append(["Reporting currency", currency, currency, Self.number(values.compactMap(\.reportingTotal).reduce(Decimal.zero, +))])
        }
        for category in ExpenseCategory.allCases {
            for (currency, values) in Dictionary(grouping: receipts.filter { $0.category == category }, by: \.currencyCode).sorted(by: { $0.key < $1.key }) {
                rows.append(["Category", category.rawValue, currency, Self.number(values.reduce(Decimal.zero) { $0 + $1.total })])
            }
        }
        let dates = Dictionary(grouping: receipts, by: { Calendar.current.startOfDay(for: $0.transactionDate) })
        for (date, dateRows) in dates.sorted(by: { $0.key < $1.key }) {
            for (currency, values) in Dictionary(grouping: dateRows, by: \.currencyCode).sorted(by: { $0.key < $1.key }) {
                rows.append(["Date", Self.iso.string(from: date), currency, Self.number(values.reduce(Decimal.zero) { $0 + $1.total })])
            }
        }
        return rows
    }

    private static let iso: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "en_US_POSIX"); value.dateFormat = "yyyy-MM-dd"; return value
    }()
    private static func number(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
    private static func lineItemsText(_ receipt: ExportReceiptSnapshot) -> String {
        receipt.lineItems.map { "\($0.description) [\(number($0.quantity)) × \(number($0.unitPrice)) = \(number($0.total))]" }.joined(separator: " | ")
    }
    private func safeFilename(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: #"[^A-Za-z0-9_-]"#, with: "-", options: .regularExpression)
        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    }
    private static func csvEscape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    private static func xml(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }
    private static func data(_ value: String) -> Data { Data(value.utf8) }
}

private struct ExportReceiptSnapshot: Sendable {
    let id: UUID
    let merchant: String
    let transactionDate: Date
    let currencyCode: String
    let subtotal: Decimal
    let tax: Decimal
    let tip: Decimal
    let discount: Decimal
    let taxLabel: String
    let total: Decimal
    let category: ExpenseCategory
    let notes: String
    let ocrConfidence: Double
    let reviewStatus: ReceiptReviewStatus
    let validationNotes: String
    let paymentMethod: PaymentMethod
    let reimbursementStatus: ReimbursementStatus
    let tagsRaw: String
    let clientOrCostCentre: String
    let reportingCurrencyCode: String
    let exchangeRate: Decimal
    let exchangeRateDate: Date?
    let exchangeRateSource: String
    let matterName: String?
    let pages: [ExportPageSnapshot]
    let revisions: [ExportRevisionSnapshot]
    let lineItems: [ReceiptLineItem]
    let fieldConfidence: ReceiptFieldConfidence
    let originalEvidenceDigest: String
    let currentEvidenceDigest: String
    let evidenceSealedAt: Date?

    @MainActor
    init(_ receipt: Receipt) {
        id = receipt.id
        merchant = receipt.merchant
        transactionDate = receipt.transactionDate
        currencyCode = receipt.currencyCode
        subtotal = receipt.subtotal
        tax = receipt.tax
        tip = receipt.tip
        discount = receipt.discount
        taxLabel = receipt.taxLabel
        total = receipt.total
        category = receipt.category
        notes = receipt.notes
        ocrConfidence = receipt.ocrConfidence
        reviewStatus = receipt.reviewStatus
        validationNotes = receipt.validationNotes
        paymentMethod = receipt.paymentMethod
        reimbursementStatus = receipt.reimbursementStatus
        tagsRaw = receipt.tagsRaw
        clientOrCostCentre = receipt.clientOrCostCentre
        reportingCurrencyCode = receipt.reportingCurrencyCode
        exchangeRate = receipt.exchangeRate
        exchangeRateDate = receipt.exchangeRateDate
        exchangeRateSource = receipt.exchangeRateSource
        matterName = receipt.matter?.name
        pages = receipt.pages.map { ExportPageSnapshot(imageData: $0.imageData, originalImageData: $0.originalImageData, pageIndex: $0.pageIndex) }
        revisions = receipt.revisions.map(ExportRevisionSnapshot.init)
        lineItems = receipt.lineItems
        fieldConfidence = receipt.fieldConfidence
        originalEvidenceDigest = receipt.originalEvidenceDigest
        currentEvidenceDigest = receipt.currentEvidenceDigest
        evidenceSealedAt = receipt.evidenceSealedAt
    }

    var reconciliationDifference: Decimal { subtotal + tax + tip - discount - total }
    var hasCompleteConversion: Bool {
        reportingCurrencyCode.count == 3 && exchangeRate > 0 && exchangeRateDate != nil && !exchangeRateSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var reportingTotal: Decimal? { hasCompleteConversion ? total * exchangeRate : nil }
    var lineItemTotal: Decimal { lineItems.reduce(.zero) { $0 + $1.total } }
    var revisionDates: [Date] { revisions.map(\.changedAt) }
}

private struct ExportPageSnapshot: Sendable {
    let imageData: Data
    let originalImageData: Data?
    let pageIndex: Int
}

private struct ExportRevisionSnapshot: Codable, Sendable {
    let changedAt: Date
    let fieldName: String
    let previousValue: String
    let newValue: String
    let reason: String

    @MainActor
    init(_ revision: ReceiptRevision) {
        changedAt = revision.changedAt
        fieldName = revision.fieldName
        previousValue = revision.previousValue
        newValue = revision.newValue
        reason = revision.reason
    }
}

private struct ProofReceiptRecord: Codable, Sendable {
    let receiptID: UUID
    let merchant: String
    let transactionDate: Date
    let currencyCode: String
    let total: String
    let matter: String?
    let category: String
    let reviewStatus: String
    let ocrConfidence: Double
    let originalEvidenceDigest: String
    let currentEvidenceDigest: String
    let evidenceSealedAt: Date?
    let revisions: [ExportRevisionSnapshot]

    init(_ receipt: ExportReceiptSnapshot) {
        receiptID = receipt.id
        merchant = receipt.merchant
        transactionDate = receipt.transactionDate
        currencyCode = receipt.currencyCode
        total = NSDecimalNumber(decimal: receipt.total).stringValue
        matter = receipt.matterName
        category = receipt.category.rawValue
        reviewStatus = receipt.reviewStatus.title
        ocrConfidence = receipt.ocrConfidence
        originalEvidenceDigest = receipt.originalEvidenceDigest
        currentEvidenceDigest = receipt.currentEvidenceDigest
        evidenceSealedAt = receipt.evidenceSealedAt
        revisions = receipt.revisions
    }
}

struct ProofPackManifest: Codable, Equatable, Sendable {
    struct FileRecord: Codable, Equatable, Sendable {
        let path: String
        let byteCount: Int
        let sha256: String
    }

    let schemaVersion: Int
    let product: String
    let title: String
    let generatedAt: Date
    let hashAlgorithm: String
    let files: [FileRecord]
}

enum ProofPackManifestBuilder {
    static func manifestData(for files: [String: Data], title: String, generatedAt: Date = .now) throws -> Data {
        let manifest = ProofPackManifest(
            schemaVersion: 1,
            product: "ReceiptSure: Expense Proof",
            title: title,
            generatedAt: generatedAt,
            hashAlgorithm: "SHA-256",
            files: files.keys.sorted().compactMap { path in
                guard let data = files[path] else { return nil }
                return ProofPackManifest.FileRecord(path: path, byteCount: data.count, sha256: sha256Hex(data))
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(manifest)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum SpreadsheetColumnReference {
    static func name(for index: Int) -> String {
        guard index > 0 else { return "" }
        var value = index
        var result = ""
        while value > 0 {
            value -= 1
            let scalar = UnicodeScalar(65 + (value % 26))!
            result.insert(Character(scalar), at: result.startIndex)
            value /= 26
        }
        return result
    }
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
