import Foundation
import UIKit
import Vision

struct OCRDraft: Sendable {
    var merchant = ""
    var date = Date.now
    var currencyCode = Locale.current.currency?.identifier ?? "USD"
    var subtotal = Decimal.zero
    var tax = Decimal.zero
    var total = Decimal.zero
    var category = ExpenseCategory.other
    var fullText = ""
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
        let texts = try await withThrowingTaskGroup(of: String.self) { group in
            for image in images {
                group.addTask { try await Self.recognize(image: image) }
            }
            var results: [String] = []
            for try await text in group { results.append(text) }
            return results
        }

        let text = texts.joined(separator: "\n--- PAGE ---\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReceiptOCRError.noText
        }
        return Self.parse(text: text)
    }

    private static func recognize(image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ReceiptOCRError.invalidImage }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
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

    private static func parse(text: String) -> OCRDraft {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var draft = OCRDraft()
        draft.fullText = text
        draft.merchant = lines.first(where: { $0.rangeOfCharacter(from: .letters) != nil }) ?? ""
        draft.currencyCode = detectCurrency(in: text)

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let date = match.date {
            draft.date = date
        }

        let amountsByLine = lines.map { ($0, amounts(in: $0)) }
        draft.tax = bestAmount(in: amountsByLine, labels: ["tax", "gst", "vat", "service charge"]) ?? .zero
        draft.subtotal = bestAmount(in: amountsByLine, labels: ["subtotal", "sub total", "net"]) ?? .zero
        draft.total = bestAmount(in: amountsByLine, labels: ["grand total", "amount due", "total", "paid"])
            ?? amountsByLine.flatMap { $0.1 }.max() ?? .zero
        if draft.subtotal == .zero, draft.total >= draft.tax { draft.subtotal = draft.total - draft.tax }
        draft.category = inferCategory(from: text.lowercased())
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
