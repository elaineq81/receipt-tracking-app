import CryptoKit
import Foundation

enum EvidenceIntegrityService {
    static func digest(_ pages: [(index: Int, data: Data)]) -> String {
        var hasher = SHA256()
        for page in pages.sorted(by: { $0.index < $1.index }) {
            hasher.update(data: Data("ReceiptSure:evidence:v1:page:\(page.index):\(page.data.count):".utf8))
            hasher.update(data: page.data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func currentDigest(for receipt: Receipt) -> String {
        digest(receipt.pages.map { ($0.pageIndex, $0.imageData) })
    }

    static func originalDigest(for receipt: Receipt) -> String {
        digest(receipt.pages.map { ($0.pageIndex, $0.originalImageData ?? $0.imageData) })
    }

    static func seal(_ receipt: Receipt, at date: Date = .now) {
        if receipt.originalEvidenceDigest.isEmpty {
            receipt.originalEvidenceDigest = originalDigest(for: receipt)
        }
        receipt.currentEvidenceDigest = currentDigest(for: receipt)
        receipt.evidenceSealedAt = date
    }

    static func verify(_ receipt: Receipt) -> EvidenceIntegrityStatus {
        guard !receipt.currentEvidenceDigest.isEmpty else { return .notSealed }
        return currentDigest(for: receipt) == receipt.currentEvidenceDigest ? .verified : .changed
    }
}

enum EvidenceIntegrityStatus: Equatable {
    case verified
    case changed
    case notSealed

    var title: String {
        switch self {
        case .verified: "Evidence integrity verified"
        case .changed: "Evidence has changed since sealing"
        case .notSealed: "Evidence not yet sealed"
        }
    }

    var symbol: String {
        switch self {
        case .verified: "checkmark.shield.fill"
        case .changed: "exclamationmark.shield.fill"
        case .notSealed: "shield"
        }
    }
}
