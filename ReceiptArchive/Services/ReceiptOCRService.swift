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
            for image in images {
                group.addTask { try await Self.recognize(image: image) }
            }
            var results: [RecognizedPage] = []
            for try await page in group { results.append(page) }
            return results
        }

        let text = pages.map(\.text).joined(separator: "\n--- PAGE ---\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReceiptOCRError.noText
        }
        let confidence = pages.isEmpty ? 0 : pages.map(\.confidence).reduce(0, +) / Double(pages.count)
        return Self.parse(text: text, confidence: confidence)
    }

    private struct RecognizedPage: Sendable { let text: String; let confidence: Double }

    private static func recognize(image: UIImage) async throws -> RecognizedPage {
        guard let cgImage = image.cgImage else { throw ReceiptOCRError.invalidImage }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let candidates = observations.compactMap { $0.topCandidates(1).first }
                let text = candidates.map(\.string).joined(separator: "\n")
                let confidence = candidates.isEmpty ? 0 : candidates.map { Double($0.confidence) }.reduce(0, +) / Double(candidates.count)
                continuation.resume(returning: RecognizedPage(text: text, confidence: confidence))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-GB", "zh-Hans", "zh-Hant"]
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func parse(text: String, confidence: Double) -> OCRDraft {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var draft = OCRDraft()
        draft.fullText = text
        draft.confidence = confidence
        draft.merchant = lines.first(where: { $0.rangeOfCharacter(from: .letters) != nil }) ?? ""
        draft.currencyCode = detectCurrency(in: text)

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let date = match.date {
            draft.date = date
        }

        let amountsByLine = lines.map { ($0, amounts(in: $0)) }
        draft.tax = bestAmount(in: amountsByLine, labels: ["tax", "gst", "vat", "service charge"]) ?? .zero
        draft.tip = bestAmount(in: amountsByLine, labels: ["tip", "gratuity"]) ?? .zero
        draft.discount = bestAmount(in: amountsByLine, labels: ["discount", "coupon", "savings"]) ?? .zero
        if text.localizedCaseInsensitiveContains("GST") { draft.taxLabel = "GST" }
        else if text.localizedCaseInsensitiveContains("VAT") { draft.taxLabel = "VAT" }
        draft.subtotal = bestAmount(in: amountsByLine, labels: ["subtotal", "sub total", "net"]) ?? .zero
        draft.total = bestAmount(in: amountsByLine, labels: ["grand total", "amount due", "total", "paid"])
            ?? amountsByLine.flatMap { $0.1 }.max() ?? .zero
        if draft.subtotal == .zero, draft.total >= draft.tax + draft.tip - draft.discount { draft.subtotal = draft.total - draft.tax - draft.tip + draft.discount }
        draft.category = inferCategory(from: text.lowercased())
        draft.warnings = ReceiptEvidence.warnings(merchant: draft.merchant, date: draft.date, subtotal: draft.subtotal, tax: draft.tax, tip: draft.tip, discount: draft.discount, total: draft.total, currencyCode: draft.currencyCode, ocrConfidence: confidence)
        return draft
    }

    private static func amounts(in line: String) -> [Decimal] {
        let pattern = #"(?<!\d)(?:\d{1,3}(?:[ ,.']\d{3})*|\d+)[.,]\d{2}(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap { match in
            guard let range = Range(match.range, in: line) else { return nil }
            var value = String(line[range]).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "'", with: "")
            if value.filter({ $0 == "," }).count == 1 && !value.contains(".") {
                value = value.replacingOccurrences(of: ",", with: ".")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
            return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
        }
    }

    private static func bestAmount(in lines: [(String, [Decimal])], labels: [String]) -> Decimal? {
        for label in labels {
            if let match = lines.reversed().first(where: { $0.0.lowercased().contains(label) }),
               let value = match.1.last { return value }
        }
        return nil
    }

    private static func detectCurrency(in text: String) -> String {
        let upper = text.uppercased()
        for code in ["SGD", "USD", "EUR", "GBP", "AUD", "CAD", "JPY", "CNY", "HKD", "MYR", "THB", "IDR", "INR"] {
            if upper.contains(code) { return code }
        }
        if text.contains("S$") { return "SGD" }
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("¥") { return "JPY" }
        if text.contains("$") { return Locale.current.currency?.identifier ?? "USD" }
        return Locale.current.currency?.identifier ?? "USD"
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
