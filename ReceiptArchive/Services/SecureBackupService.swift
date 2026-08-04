import CryptoKit
import Foundation
import Security
import SwiftData

enum SecureBackupError: LocalizedError {
    case passwordTooShort
    case invalidArchive
    case unsupportedVersion
    case wrongPassword

    var errorDescription: String? {
        switch self {
        case .passwordTooShort: "Use a backup password with at least 8 characters."
        case .invalidArchive: "This is not a valid Receipt Archive backup."
        case .unsupportedVersion: "This backup was created by an unsupported app version."
        case .wrongPassword: "The password is incorrect or the backup is damaged."
        }
    }
}

struct RestoreSummary: Sendable {
    let matters: Int
    let receipts: Int
    let rules: Int
    let skippedReceipts: Int
}

@MainActor
enum SecureBackupService {
    static func create(modelContext: ModelContext, password: String) async throws -> URL {
        guard password.count >= 8 else { throw SecureBackupError.passwordTooShort }
        let payload = try snapshot(modelContext: modelContext)
        let encrypted = try await Task.detached {
            let encoded = try JSONEncoder.backupEncoder.encode(payload)
            return try SecureArchiveCrypto.seal(encoded, password: password)
        }.value
        let url = FileManager.default.temporaryDirectory.appending(path: "ReceiptArchive-\(Date.now.formatted(.iso8601.year().month().day())).receiptarchive")
        try encrypted.write(to: url, options: .atomic)
        return url
    }

    static func restore(from url: URL, modelContext: ModelContext, password: String) async throws -> RestoreSummary {
        guard password.count >= 8 else { throw SecureBackupError.passwordTooShort }
        let decoded = try await Task.detached {
            let encrypted = try Data(contentsOf: url)
            let clear = try SecureArchiveCrypto.open(encrypted, password: password)
            return try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: clear)
        }.value
        guard decoded.version == 1 else { throw SecureBackupError.unsupportedVersion }
        return try merge(decoded, into: modelContext)
    }

    private static func snapshot(modelContext: ModelContext) throws -> BackupPayload {
        let matters = try modelContext.fetch(FetchDescriptor<ExpenseMatter>()).map(MatterRecord.init)
        let receipts = try modelContext.fetch(FetchDescriptor<Receipt>()).map(ReceiptRecord.init)
        let rules = try modelContext.fetch(FetchDescriptor<MerchantRule>()).map(RuleRecord.init)
        return BackupPayload(version: 1, createdAt: .now, matters: matters, receipts: receipts, rules: rules)
    }

    private static func merge(_ payload: BackupPayload, into modelContext: ModelContext) throws -> RestoreSummary {
        let currentMatters = try modelContext.fetch(FetchDescriptor<ExpenseMatter>())
        var mattersByID = Dictionary(uniqueKeysWithValues: currentMatters.map { ($0.id, $0) })
        var addedMatters = 0
        for row in payload.matters where mattersByID[row.id] == nil {
            let matter = ExpenseMatter(id: row.id, name: row.name, details: row.details, startDate: row.startDate, endDate: row.endDate, colorName: row.colorName)
            matter.createdAt = row.createdAt
            modelContext.insert(matter)
            mattersByID[row.id] = matter
            addedMatters += 1
        }

        let currentReceiptIDs = Set(try modelContext.fetch(FetchDescriptor<Receipt>()).map(\.id))
        var addedReceipts = 0
        var skippedReceipts = 0
        for row in payload.receipts {
            guard !currentReceiptIDs.contains(row.id) else { skippedReceipts += 1; continue }
            let receipt = row.makeReceipt(matter: row.matterID.flatMap { mattersByID[$0] })
            modelContext.insert(receipt)
            for (index, data) in row.pages.enumerated() {
                let page = ReceiptPage(imageData: data, pageIndex: index)
                modelContext.insert(page)
                receipt.pages.append(page)
            }
            for row in row.revisions {
                let revision = ReceiptRevision(id: row.id, changedAt: row.changedAt, fieldName: row.fieldName, previousValue: row.previousValue, newValue: row.newValue, reason: row.reason)
                modelContext.insert(revision)
                receipt.revisions.append(revision)
            }
            addedReceipts += 1
        }

        let currentRuleIDs = Set(try modelContext.fetch(FetchDescriptor<MerchantRule>()).map(\.id))
        var addedRules = 0
        for row in payload.rules where !currentRuleIDs.contains(row.id) {
            let rule = MerchantRule(id: row.id, merchantPattern: row.merchantPattern, category: ExpenseCategory(rawValue: row.categoryRaw) ?? .other, paymentMethod: PaymentMethod(rawValue: row.paymentMethodRaw) ?? .unspecified, tags: row.tags, clientOrCostCentre: row.clientOrCostCentre, matterID: row.matterID)
            rule.createdAt = row.createdAt
            modelContext.insert(rule)
            addedRules += 1
        }
        try modelContext.save()
        return RestoreSummary(matters: addedMatters, receipts: addedReceipts, rules: addedRules, skippedReceipts: skippedReceipts)
    }
}

private enum SecureArchiveCrypto {
    private static let magic = Data("RARC2".utf8)

    static func seal(_ clear: Data, password: String) throws -> Data {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, bytes.baseAddress!)
        }
        guard status == errSecSuccess else { throw SecureBackupError.invalidArchive }
        let key = deriveKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(clear, using: key)
        guard let combined = sealed.combined else { throw SecureBackupError.invalidArchive }
        return magic + salt + combined
    }

    static func open(_ archive: Data, password: String) throws -> Data {
        guard archive.count > magic.count + 16, archive.prefix(magic.count) == magic else { throw SecureBackupError.invalidArchive }
        let saltStart = magic.count
        let salt = archive.subdata(in: saltStart..<(saltStart + 16))
        let combined = archive.subdata(in: (saltStart + 16)..<archive.count)
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: deriveKey(password: password, salt: salt))
        } catch {
            throw SecureBackupError.wrongPassword
        }
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        var blockIndex = UInt32(1).bigEndian
        let indexData = withUnsafeBytes(of: &blockIndex) { Data($0) }
        var previous = Data(HMAC<SHA256>.authenticationCode(for: salt + indexData, using: passwordKey))
        var derived = [UInt8](previous)
        for _ in 1..<100_000 {
            previous = Data(HMAC<SHA256>.authenticationCode(for: previous, using: passwordKey))
            let bytes = [UInt8](previous)
            for index in derived.indices { derived[index] ^= bytes[index] }
        }
        return SymmetricKey(data: Data(derived))
    }
}

private struct BackupPayload: Codable, Sendable {
    let version: Int
    let createdAt: Date
    let matters: [MatterRecord]
    let receipts: [ReceiptRecord]
    let rules: [RuleRecord]
}

private struct MatterRecord: Codable, Sendable {
    let id: UUID; let name: String; let details: String; let startDate: Date; let endDate: Date?; let createdAt: Date; let colorName: String
    init(_ value: ExpenseMatter) { id = value.id; name = value.name; details = value.details; startDate = value.startDate; endDate = value.endDate; createdAt = value.createdAt; colorName = value.colorName }
}

private struct RevisionRecord: Codable, Sendable {
    let id: UUID; let changedAt: Date; let fieldName: String; let previousValue: String; let newValue: String; let reason: String
    init(_ value: ReceiptRevision) { id = value.id; changedAt = value.changedAt; fieldName = value.fieldName; previousValue = value.previousValue; newValue = value.newValue; reason = value.reason }
}

private struct ReceiptRecord: Codable, Sendable {
    let id: UUID; let merchant: String; let transactionDate: Date; let currencyCode: String
    let subtotal: Decimal; let tax: Decimal; let tip: Decimal; let discount: Decimal; let taxLabel: String; let total: Decimal
    let categoryRaw: String; let notes: String; let createdAt: Date; let ocrText: String; let ocrConfidence: Double
    let reviewStatusRaw: String; let reviewedAt: Date?; let validationNotes: String; let fingerprint: String
    let paymentMethodRaw: String; let reimbursementStatusRaw: String; let tagsRaw: String; let clientOrCostCentre: String
    let reportingCurrencyCode: String; let exchangeRate: Decimal; let exchangeRateDate: Date?; let exchangeRateSource: String
    let matterID: UUID?; let pages: [Data]; let revisions: [RevisionRecord]

    init(_ value: Receipt) {
        id = value.id; merchant = value.merchant; transactionDate = value.transactionDate; currencyCode = value.currencyCode
        subtotal = value.subtotal; tax = value.tax; tip = value.tip; discount = value.discount; taxLabel = value.taxLabel; total = value.total
        categoryRaw = value.categoryRaw; notes = value.notes; createdAt = value.createdAt; ocrText = value.ocrText; ocrConfidence = value.ocrConfidence
        reviewStatusRaw = value.reviewStatusRaw; reviewedAt = value.reviewedAt; validationNotes = value.validationNotes; fingerprint = value.fingerprint
        paymentMethodRaw = value.paymentMethodRaw; reimbursementStatusRaw = value.reimbursementStatusRaw; tagsRaw = value.tagsRaw; clientOrCostCentre = value.clientOrCostCentre
        reportingCurrencyCode = value.reportingCurrencyCode; exchangeRate = value.exchangeRate; exchangeRateDate = value.exchangeRateDate; exchangeRateSource = value.exchangeRateSource
        matterID = value.matter?.id; pages = value.pages.sorted(by: { $0.pageIndex < $1.pageIndex }).map(\.imageData); revisions = value.revisions.map(RevisionRecord.init)
    }

    func makeReceipt(matter: ExpenseMatter?) -> Receipt {
        let value = Receipt(id: id, merchant: merchant, transactionDate: transactionDate, currencyCode: currencyCode, subtotal: subtotal, tax: tax, tip: tip, discount: discount, taxLabel: taxLabel, total: total, category: ExpenseCategory(rawValue: categoryRaw) ?? .other, notes: notes, ocrText: ocrText, ocrConfidence: ocrConfidence, reviewStatus: ReceiptReviewStatus(rawValue: reviewStatusRaw) ?? .needsReview, reviewedAt: reviewedAt, validationNotes: validationNotes, fingerprint: fingerprint, paymentMethod: PaymentMethod(rawValue: paymentMethodRaw) ?? .unspecified, reimbursementStatus: ReimbursementStatus(rawValue: reimbursementStatusRaw) ?? .notApplicable, tags: tagsRaw, clientOrCostCentre: clientOrCostCentre, reportingCurrencyCode: reportingCurrencyCode, exchangeRate: exchangeRate, exchangeRateDate: exchangeRateDate, exchangeRateSource: exchangeRateSource, matter: matter)
        value.createdAt = createdAt
        return value
    }
}

private struct RuleRecord: Codable, Sendable {
    let id: UUID; let merchantPattern: String; let categoryRaw: String; let paymentMethodRaw: String; let tags: String; let clientOrCostCentre: String; let matterID: UUID?; let createdAt: Date
    init(_ value: MerchantRule) { id = value.id; merchantPattern = value.merchantPattern; categoryRaw = value.categoryRaw; paymentMethodRaw = value.paymentMethodRaw; tags = value.tags; clientOrCostCentre = value.clientOrCostCentre; matterID = value.matterID; createdAt = value.createdAt }
}

private extension JSONEncoder {
    static var backupEncoder: JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }
}

private extension JSONDecoder {
    static var backupDecoder: JSONDecoder { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }
}
