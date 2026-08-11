import Foundation
import UIKit
import Vision

struct OCRDraft: Sendable {
    var merchant = ""
    var date = Date.now
    var currencyCode = Locale.current.currency?.identifier ?? "USD"
    var subtotal = Decimal.zero
    var tax = Decimal.zero
    var tip = Decimal.zero
    var discount = Decimal.zero
    var taxLabel = "Tax"
    var total = Decimal.zero
    var category = ExpenseCategory.other
    var fullText = ""
    var confidence: Double = 0
    var fieldConfidence = ReceiptFieldConfidence.empty
    var lineItems: [ReceiptLineItem] = []
    var warnings: [String] = []
}

struct ReceiptEvidence {
    static func warnings(merchant: String, date: Date, subtotal: Decimal, tax: Decimal, tip: Decimal = 0, discount: Decimal = 0, total: Decimal, currencyCode: String, ocrConfidence: Double, reportingCurrencyCode: String = "", exchangeRate: Decimal = 0, exchangeRateDate: Date? = nil, exchangeRateSource: String = "") -> [String] {
        var issues: [String] = []
        if merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Merchant is missing") }
        if total <= 0 { issues.append("Total must be checked") }
        if tax < 0 || subtotal < 0 { issues.append("Negative figures need checking") }
        if tip < 0 || discount < 0 { issues.append("Tip and discount cannot be negative") }
        if subtotal > 0, tax >= 0, abs(NSDecimalNumber(decimal: subtotal + tax + tip - discount - total).doubleValue) > 0.02 {
            issues.append("Subtotal, tax, tip and discount do not reconcile to total")
        }
        if currencyCode.count != 3 { issues.append("Currency code is incomplete") }
        if date > Calendar.current.date(byAdding: .day, value: 1, to: .now)! { issues.append("Date appears to be in the future") }
        if ocrConfidence < 0.72 { issues.append("Scan confidence is low") }
        let hasAnyConversion = !reportingCurrencyCode.isEmpty || exchangeRate > 0 || exchangeRateDate != nil || !exchangeRateSource.isEmpty
        let hasCompleteConversion = reportingCurrencyCode.count == 3 && exchangeRate > 0 && exchangeRateDate != nil && !exchangeRateSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasAnyConversion && !hasCompleteConversion { issues.append("Currency conversion provenance is incomplete") }
        return issues
    }

    static func fingerprint(merchant: String, date: Date, total: Decimal, currencyCode: String) -> String {
        let normalizedMerchant = merchant.lowercased().filter(\.isLetter)
        let day = date.formatted(.iso8601.year().month().day())
        let amount = NSDecimalNumber(decimal: total).stringValue
        return "\(normalizedMerchant)|\(day)|\(currencyCode.uppercased())|\(amount)"
    }
}

enum ReceiptOCRError: LocalizedError {
    case invalidImage
    case noText

    var errorDescription: String? {
        switch self {
        case .invalidImage: "The receipt image could not be read."
        case .noText: "No readable text was found. You can still enter the receipt manually."
        }
    }
}

actor ReceiptOCRService {
    func recognize(images: [UIImage]) async throws -> OCRDraft {
        let pages = try await withThrowingTaskGroup(of: RecognizedPage.self) { group in
            for (index, image) in images.enumerated() {
                group.addTask { try await Self.recognize(image: image, pageIndex: index) }
            }
            var results: [RecognizedPage] = []
            for try await page in group { results.append(page) }
            return results
        }

        let orderedPages = pages.sorted(by: { $0.pageIndex < $1.pageIndex })
        let text = orderedPages.map(\.text).joined(separator: "\n--- PAGE ---\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReceiptOCRError.noText
        }
        let confidence = orderedPages.isEmpty ? 0 : orderedPages.map(\.confidence).reduce(0, +) / Double(orderedPages.count)
        return Self.parse(lines: orderedPages.flatMap(\.lines), text: text, confidence: confidence)
    }

    private struct RecognizedLine: Sendable {
        let text: String
        let confidence: Double
    }

    private struct RecognizedPage: Sendable {
        let pageIndex: Int
        let lines: [RecognizedLine]
        var text: String { lines.map(\.text).joined(separator: "\n") }
        var confidence: Double { lines.isEmpty ? 0 : lines.map(\.confidence).reduce(0, +) / Double(lines.count) }
    }

    private static func recognize(image: UIImage, pageIndex: Int) async throws -> RecognizedPage {
        guard let cgImage = image.cgImage else { throw ReceiptOCRError.invalidImage }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .sorted {
                        if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 {
                            return $0.boundingBox.midY > $1.boundingBox.midY
                        }
                        return $0.boundingBox.minX < $1.boundingBox.minX
                    }
                let lines = observations.compactMap { observation -> RecognizedLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedLine(text: candidate.string, confidence: Double(candidate.confidence))
                }
                continuation.resume(returning: RecognizedPage(pageIndex: pageIndex, lines: lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            if let supported = try? request.supportedRecognitionLanguages() {
                let preferredLanguageCodes = Locale.preferredLanguages.map {
                    String($0.prefix(2)).lowercased()
                }
                let preferred = supported.filter { language in
                    preferredLanguageCodes.contains(String(language.prefix(2)).lowercased())
                }
                let common = ["en-US", "en-GB", "zh-Hans", "zh-Hant", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "nl-NL", "ja-JP", "ko-KR"]
                    .filter(supported.contains)
                request.recognitionLanguages = Array((preferred + common).uniqued().prefix(12))
            }
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func parse(lines recognizedLines: [RecognizedLine], text: String, confidence: Double) -> OCRDraft {
        let lines = recognizedLines.compactMap { line -> RecognizedLine? in
            let cleaned = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : RecognizedLine(text: cleaned, confidence: line.confidence)
        }
        var draft = OCRDraft()
        draft.fullText = text
        draft.confidence = confidence
        let merchantLine = lines.first(where: { $0.text.rangeOfCharacter(from: .letters) != nil })
        draft.merchant = merchantLine?.text ?? ""
        draft.fieldConfidence.merchant = merchantLine?.confidence ?? 0

        let currency = detectCurrency(in: lines)
        draft.currencyCode = currency.value
        draft.fieldConfidence.currency = currency.confidence

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            for line in lines {
                if let match = detector.firstMatch(in: line.text, range: NSRange(line.text.startIndex..., in: line.text)),
                   let date = match.date {
                    draft.date = date
                    draft.fieldConfidence.date = line.confidence
                    break
                }
            }
        }

        let amountsByLine = lines.map { ($0, ReceiptTextParsing.amounts(in: $0.text)) }
        let tax = bestAmount(in: amountsByLine, labels: ["tax", "gst", "vat", "service charge"])
        draft.tax = tax?.value ?? .zero
        draft.fieldConfidence.tax = tax?.confidence ?? 0
        draft.tip = bestAmount(in: amountsByLine, labels: ["tip", "gratuity"])?.value ?? .zero
        draft.discount = bestAmount(in: amountsByLine, labels: ["discount", "coupon", "savings"])?.value ?? .zero
        if text.localizedCaseInsensitiveContains("GST") { draft.taxLabel = "GST" }
        else if text.localizedCaseInsensitiveContains("VAT") { draft.taxLabel = "VAT" }
        let subtotal = bestAmount(in: amountsByLine, labels: ["subtotal", "sub total", "net"])
        draft.subtotal = subtotal?.value ?? .zero
        draft.fieldConfidence.subtotal = subtotal?.confidence ?? 0
        let total = bestAmount(in: amountsByLine, labels: ["grand total", "amount due", "total", "paid"])
        if let total {
            draft.total = total.value
            draft.fieldConfidence.total = total.confidence
        } else if let fallback = amountsByLine.flatMap({ row in row.1.map { (value: $0, confidence: row.0.confidence) } }).max(by: { $0.value < $1.value }) {
            draft.total = fallback.value
            draft.fieldConfidence.total = fallback.confidence * 0.65
        }
        if draft.subtotal == .zero, draft.total >= draft.tax + draft.tip - draft.discount {
            draft.subtotal = draft.total - draft.tax - draft.tip + draft.discount
            draft.fieldConfidence.subtotal = max(0.3, min(draft.fieldConfidence.total, draft.fieldConfidence.tax) * 0.7)
        }
        draft.lineItems = extractLineItems(from: lines)
        draft.fieldConfidence.lineItems = draft.lineItems.isEmpty ? 0 : draft.lineItems.map(\.confidence).reduce(0, +) / Double(draft.lineItems.count)
        draft.category = inferCategory(from: text.lowercased())
        draft.warnings = ReceiptEvidence.warnings(merchant: draft.merchant, date: draft.date, subtotal: draft.subtotal, tax: draft.tax, tip: draft.tip, discount: draft.discount, total: draft.total, currencyCode: draft.currencyCode, ocrConfidence: confidence)
        if draft.fieldConfidence.minimumKeyField < 0.65 {
            draft.warnings.append("One or more key fields has low confidence")
        }
        return draft
    }

    private static func bestAmount(in lines: [(RecognizedLine, [Decimal])], labels: [String]) -> (value: Decimal, confidence: Double)? {
        for label in labels {
            if let match = lines.reversed().first(where: { $0.0.text.lowercased().contains(label) }),
               let value = match.1.last { return (value, match.0.confidence) }
        }
        return nil
    }

    private static func detectCurrency(in lines: [RecognizedLine]) -> (value: String, confidence: Double) {
        let fallback = Locale.current.currency?.identifier ?? "USD"
        let detection = ReceiptTextParsing.currency(in: lines.map(\.text), defaultCode: fallback)
        let confidence = detection.lineIndex.flatMap { lines.indices.contains($0) ? lines[$0].confidence : nil } ?? 1
        return (detection.code, confidence * detection.confidenceMultiplier)
    }

    private static func extractLineItems(from lines: [RecognizedLine]) -> [ReceiptLineItem] {
        let excludedLabels = ["subtotal", "sub total", "total", "tax", "gst", "vat", "tip", "gratuity", "discount", "coupon", "savings", "amount due", "balance", "change", "cash", "tender", "paid"]
        return lines.compactMap { line in
            let lower = line.text.lowercased()
            guard !excludedLabels.contains(where: lower.contains),
                  line.text.rangeOfCharacter(from: .letters) != nil,
                  let regex = try? NSRegularExpression(pattern: ReceiptTextParsing.amountPattern),
                  let match = regex.matches(in: line.text, range: NSRange(line.text.startIndex..., in: line.text)).last,
                  let amountRange = Range(match.range, in: line.text),
                  let total = ReceiptTextParsing.amounts(in: String(line.text[amountRange])).first,
                  total > 0 else { return nil }

            var description = String(line.text[..<amountRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            description = description.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            guard description.count >= 2 else { return nil }

            var quantity = Decimal(1)
            var unitPrice = total
            if let quantityRegex = try? NSRegularExpression(pattern: #"(?i)(\d+(?:[.,]\d+)?)\s*[x@]\s*(\d+(?:[.,]\d{2})?)"#),
               let quantityMatch = quantityRegex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
               let quantityRange = Range(quantityMatch.range(at: 1), in: description) {
                let value = String(description[quantityRange]).replacingOccurrences(of: ",", with: ".")
                if let parsed = Decimal(string: value), parsed > 0 {
                    quantity = parsed
                    if let unitRange = Range(quantityMatch.range(at: 2), in: description),
                       let parsedUnit = Decimal(string: String(description[unitRange]).replacingOccurrences(of: ",", with: ".")) {
                        unitPrice = parsedUnit
                    } else {
                        unitPrice = total / parsed
                    }
                    description = quantityRegex.stringByReplacingMatches(in: description, range: NSRange(description.startIndex..., in: description), withTemplate: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return ReceiptLineItem(description: description, quantity: quantity, unitPrice: unitPrice, total: total, confidence: line.confidence)
        }
        .prefix(100)
        .map { $0 }
    }

    private static func inferCategory(from text: String) -> ExpenseCategory {
        let rules: [(ExpenseCategory, [String])] = [
            (.accommodation, ["hotel", "hostel", "lodging", "room"]),
            (.meals, ["restaurant", "cafe", "coffee", "food", "dining"]),
            (.transport, ["taxi", "uber", "grab", "train", "airline", "parking"]),
            (.fuel, ["petrol", "gasoline", "diesel", "fuel"]),
            (.supplies, ["office", "stationery", "hardware", "supplies"]),
            (.entertainment, ["cinema", "museum", "ticket", "theatre"]),
            (.fees, ["fee", "toll", "commission"])
        ]
        return rules.first(where: { $0.1.contains(where: text.contains) })?.0 ?? .other
    }
}

struct ReceiptCurrencyDetection: Equatable, Sendable {
    let code: String
    let lineIndex: Int?
    let confidenceMultiplier: Double
}

enum ReceiptTextParsing {
    static let amountPattern = #"(?<!\d)(?:\d{1,3}(?:[ ,.']\d{3})*|\d+)[.,]\d{2}(?!\d)"#

    static func amounts(in line: String) -> [Decimal] {
        guard let regex = try? NSRegularExpression(pattern: amountPattern) else { return [] }
        return regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap { match in
            guard let range = Range(match.range, in: line) else { return nil }
            return decimal(from: String(line[range]))
        }
    }

    static func decimal(from source: String) -> Decimal? {
        var value = source
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
        let lastComma = value.lastIndex(of: ",")
        let lastDot = value.lastIndex(of: ".")

        if let lastComma, let lastDot {
            if lastComma > lastDot {
                value = value.replacingOccurrences(of: ".", with: "")
                value = replacingLastOccurrence(of: ",", with: ".", in: value)
                value = value.replacingOccurrences(of: ",", with: "")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
        } else if lastComma != nil {
            value = replacingLastOccurrence(of: ",", with: ".", in: value)
            value = value.replacingOccurrences(of: ",", with: "")
        } else if value.filter({ $0 == "." }).count > 1 {
            value = replacingLastOccurrence(of: ".", with: "#", in: value)
            value = value.replacingOccurrences(of: ".", with: "")
            value = value.replacingOccurrences(of: "#", with: ".")
        }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func currency(in lines: [String], defaultCode: String) -> ReceiptCurrencyDetection {
        let codes = [
            "AED", "ARS", "AUD", "BRL", "CAD", "CHF", "CLP", "CNY", "COP", "CZK", "DKK", "EGP", "EUR", "GBP",
            "HKD", "HUF", "IDR", "ILS", "INR", "JPY", "KRW", "MXN", "MYR", "NOK", "NZD", "PHP", "PLN", "RON",
            "RUB", "SAR", "SEK", "SGD", "THB", "TRY", "TWD", "USD", "VND", "ZAR"
        ]
        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            if let code = codes.first(where: { upper.range(of: #"\b"# + $0 + #"\b"#, options: .regularExpression) != nil }) {
                return ReceiptCurrencyDetection(code: code, lineIndex: index, confidenceMultiplier: 1)
            }
        }

        let symbols: [(String, String)] = [
            ("HK$", "HKD"), ("NZ$", "NZD"), ("US$", "USD"), ("S$", "SGD"), ("A$", "AUD"), ("C$", "CAD"),
            ("R$", "BRL"), ("€", "EUR"), ("£", "GBP"), ("₹", "INR"), ("₩", "KRW"), ("₱", "PHP"), ("฿", "THB"),
            ("₫", "VND"), ("₽", "RUB"), ("₺", "TRY"), ("₪", "ILS"), ("د.إ", "AED"), ("ر.س", "SAR")
        ]
        for (index, line) in lines.enumerated() {
            if let match = symbols.first(where: { line.localizedCaseInsensitiveContains($0.0) }) {
                return ReceiptCurrencyDetection(code: match.1, lineIndex: index, confidenceMultiplier: 0.95)
            }
            if line.contains("¥") {
                let code = ["CNY", "JPY"].contains(defaultCode.uppercased()) ? defaultCode.uppercased() : "JPY"
                return ReceiptCurrencyDetection(code: code, lineIndex: index, confidenceMultiplier: 0.8)
            }
        }

        if let index = lines.firstIndex(where: { $0.contains("$") }) {
            let dollarCodes = ["AUD", "CAD", "HKD", "NZD", "SGD", "TWD", "USD"]
            let code = dollarCodes.contains(defaultCode.uppercased()) ? defaultCode.uppercased() : "USD"
            return ReceiptCurrencyDetection(code: code, lineIndex: index, confidenceMultiplier: 0.7)
        }
        return ReceiptCurrencyDetection(code: defaultCode.uppercased(), lineIndex: nil, confidenceMultiplier: 0.35)
    }

    private static func replacingLastOccurrence(of target: Character, with replacement: Character, in source: String) -> String {
        guard let index = source.lastIndex(of: target) else { return source }
        var value = source
        value.replaceSubrange(index...index, with: String(replacement))
        return value
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
