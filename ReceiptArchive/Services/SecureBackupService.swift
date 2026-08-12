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
        case .invalidArchive: "This is not a valid ReceiptSure backup."
        case .unsupportedVersion: "This backup was created by an unsupported app version."
        case .wrongPassword: "The password is incorrect or the backup is damaged."
        }
    }
}

enum PrivateCloudSnapshotError: LocalizedError {
    case invalidSnapshot

    var errorDescription: String? { "The private iCloud snapshot is invalid or cannot be decrypted on this Apple Account." }
}

struct RestoreSummary: Sendable {
    let matters: Int
    let receipts: Int
    let rules: Int
    let categories: Int
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
        let url = FileManager.default.temporaryDirectory.appending(path: "ReceiptSure-\(Date.now.formatted(.iso8601.year().month().day())).receiptarchive")
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
        guard [1, 2, 3, 4].contains(decoded.version) else { throw SecureBackupError.unsupportedVersion }
        return try merge(decoded, into: modelContext)
    }

    static func createPrivateCloudSnapshot(modelContext: ModelContext, keyData: Data) async throws -> Data {
        let payload = try snapshot(modelContext: modelContext)
        return try await Task.detached {
            let encoded = try JSONEncoder.backupEncoder.encode(payload)
            return try PrivateCloudSnapshotCrypto.seal(encoded, keyData: keyData)
        }.value
    }

    static func mergePrivateCloudSnapshot(_ data: Data, modelContext: ModelContext, keyData: Data) async throws -> RestoreSummary {
        let decoded = try await Task.detached {
            let clear = try PrivateCloudSnapshotCrypto.open(data, keyData: keyData)
            return try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: clear)
        }.value
        guard decoded.version == 4 else { throw SecureBackupError.unsupportedVersion }
        return try merge(decoded, into: modelContext)
    }

    private static func snapshot(modelContext: ModelContext) throws -> BackupPayload {
        let matters = try modelContext.fetch(FetchDescriptor<ExpenseMatter>()).map(MatterRecord.init)
        let receipts = try modelContext.fetch(FetchDescriptor<Receipt>()).map(ReceiptRecord.init)
        let rules = try modelContext.fetch(FetchDescriptor<MerchantRule>()).map(RuleRecord.init)
        let categories = try modelContext.fetch(FetchDescriptor<CustomExpenseCategory>()).map(CategoryRecord.init)
        let tombstones = try modelContext.fetch(FetchDescriptor<CloudDeletionTombstone>()).map(TombstoneRecord.init)
        return BackupPayload(version: 4, createdAt: .now, matters: matters, receipts: receipts, rules: rules, categories: categories, tombstones: tombstones)
    }

    private static func merge(_ payload: BackupPayload, into modelContext: ModelContext) throws -> RestoreSummary {
        let currentTombstones = try modelContext.fetch(FetchDescriptor<CloudDeletionTombstone>())
        var tombstoneKeys = Set(currentTombstones.map { "\($0.entityTypeRaw):\($0.entityID.uuidString)" })
        for row in payload.tombstones ?? [] {
            let key = "\(row.entityTypeRaw):\(row.entityID.uuidString)"
            guard !tombstoneKeys.contains(key) else { continue }
            modelContext.insert(CloudDeletionTombstone(id: row.id, entityID: row.entityID, entityType: CloudEntityType(rawValue: row.entityTypeRaw) ?? .receipt, deletedAt: row.deletedAt))
            tombstoneKeys.insert(key)
        }
        let deletedReceiptIDs = Set(tombstoneKeys.compactMap { key -> UUID? in
            guard key.hasPrefix("\(CloudEntityType.receipt.rawValue):") else { return nil }
            return UUID(uuidString: String(key.dropFirst(CloudEntityType.receipt.rawValue.count + 1)))
        })
        let deletedRuleIDs = Set(tombstoneKeys.compactMap { key -> UUID? in
            guard key.hasPrefix("\(CloudEntityType.merchantRule.rawValue):") else { return nil }
            return UUID(uuidString: String(key.dropFirst(CloudEntityType.merchantRule.rawValue.count + 1)))
        })
        let deletedCategoryIDs = Set(tombstoneKeys.compactMap { key -> UUID? in
            guard key.hasPrefix("\(CloudEntityType.customCategory.rawValue):") else { return nil }
            return UUID(uuidString: String(key.dropFirst(CloudEntityType.customCategory.rawValue.count + 1)))
        })

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

        let currentReceipts = try modelContext.fetch(FetchDescriptor<Receipt>())
        currentReceipts.filter { deletedReceiptIDs.contains($0.id) }.forEach(modelContext.delete)
        let currentReceiptIDs = Set(currentReceipts.map(\.id)).subtracting(deletedReceiptIDs)
        var addedReceipts = 0
        var skippedReceipts = 0
        for row in payload.receipts {
            guard !deletedReceiptIDs.contains(row.id) else { continue }
            guard !currentReceiptIDs.contains(row.id) else { skippedReceipts += 1; continue }
            let receipt = row.makeReceipt(matter: row.matterID.flatMap { mattersByID[$0] })
            modelContext.insert(receipt)
            for (index, data) in row.pages.enumerated() {
                let originalData: Data?
                if let originals = row.originalPages, originals.indices.contains(index) {
                    originalData = originals[index]
                } else {
                    originalData = nil
                }
                let page = ReceiptPage(imageData: data, originalImageData: originalData, pageIndex: index)
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

        let currentRules = try modelContext.fetch(FetchDescriptor<MerchantRule>())
        currentRules.filter { deletedRuleIDs.contains($0.id) }.forEach(modelContext.delete)
        let currentRuleIDs = Set(currentRules.map(\.id)).subtracting(deletedRuleIDs)
        var addedRules = 0
        for row in payload.rules where !currentRuleIDs.contains(row.id) && !deletedRuleIDs.contains(row.id) {
            let rule = MerchantRule(id: row.id, merchantPattern: row.merchantPattern, category: ExpenseCategory(rawValue: row.categoryRaw) ?? .other, paymentMethod: PaymentMethod(rawValue: row.paymentMethodRaw) ?? .unspecified, tags: row.tags, clientOrCostCentre: row.clientOrCostCentre, matterID: row.matterID)
            rule.categoryRaw = row.categoryRaw
            rule.createdAt = row.createdAt
            modelContext.insert(rule)
            addedRules += 1
        }

        let currentCategories = try modelContext.fetch(FetchDescriptor<CustomExpenseCategory>())
        currentCategories.filter { deletedCategoryIDs.contains($0.id) }.forEach(modelContext.delete)
        let currentCategoryIDs = Set(currentCategories.map(\.id)).subtracting(deletedCategoryIDs)
        var addedCategories = 0
        for row in payload.categories ?? [] where !currentCategoryIDs.contains(row.id) && !deletedCategoryIDs.contains(row.id) {
            modelContext.insert(CustomExpenseCategory(id: row.id, name: row.name, symbolName: row.symbolName, sortOrder: row.sortOrder, createdAt: row.createdAt))
            addedCategories += 1
        }
        try modelContext.save()
        return RestoreSummary(matters: addedMatters, receipts: addedReceipts, rules: addedRules, categories: addedCategories, skippedReceipts: skippedReceipts)
    }
}

private enum PrivateCloudSnapshotCrypto {
    private static let magic = Data("RCLD1".utf8)

    static func seal(_ clear: Data, keyData: Data) throws -> Data {
        guard keyData.count == 32 else { throw PrivateCloudSnapshotError.invalidSnapshot }
        let sealed = try AES.GCM.seal(clear, using: SymmetricKey(data: keyData))
        guard let combined = sealed.combined else { throw PrivateCloudSnapshotError.invalidSnapshot }
        return magic + combined
    }

    static func open(_ archive: Data, keyData: Data) throws -> Data {
        guard keyData.count == 32, archive.count > magic.count, archive.prefix(magic.count) == magic else {
            throw PrivateCloudSnapshotError.invalidSnapshot
        }
        do {
            let box = try AES.GCM.SealedBox(combined: Data(archive.dropFirst(magic.count)))
            return try AES.GCM.open(box, using: SymmetricKey(data: keyData))
        } catch {
            throw PrivateCloudSnapshotError.invalidSnapshot
        }
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
    let categories: [CategoryRecord]?
    let tombstones: [TombstoneRecord]?
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
    let originalPages: [Data?]?
    let lineItems: [ReceiptLineItem]?
    let fieldConfidence: ReceiptFieldConfidence?
    let originalEvidenceDigest: String?
    let currentEvidenceDigest: String?
    let evidenceSealedAt: Date?
    let isTrashed: Bool?
    let trashedAt: Date?

    init(_ value: Receipt) {
        id = value.id; merchant = value.merchant; transactionDate = value.transactionDate; currencyCode = value.currencyCode
        subtotal = value.subtotal; tax = value.tax; tip = value.tip; discount = value.discount; taxLabel = value.taxLabel; total = value.total
        categoryRaw = value.categoryRaw; notes = value.notes; createdAt = value.createdAt; ocrText = value.ocrText; ocrConfidence = value.ocrConfidence
        reviewStatusRaw = value.reviewStatusRaw; reviewedAt = value.reviewedAt; validationNotes = value.validationNotes; fingerprint = value.fingerprint
        paymentMethodRaw = value.paymentMethodRaw; reimbursementStatusRaw = value.reimbursementStatusRaw; tagsRaw = value.tagsRaw; clientOrCostCentre = value.clientOrCostCentre
        reportingCurrencyCode = value.reportingCurrencyCode; exchangeRate = value.exchangeRate; exchangeRateDate = value.exchangeRateDate; exchangeRateSource = value.exchangeRateSource
        matterID = value.matter?.id; pages = value.pages.sorted(by: { $0.pageIndex < $1.pageIndex }).map(\.imageData); revisions = value.revisions.map(RevisionRecord.init)
        originalPages = value.pages.sorted(by: { $0.pageIndex < $1.pageIndex }).map(\.originalImageData)
        lineItems = value.lineItems; fieldConfidence = value.fieldConfidence
        originalEvidenceDigest = value.originalEvidenceDigest; currentEvidenceDigest = value.currentEvidenceDigest; evidenceSealedAt = value.evidenceSealedAt
        isTrashed = value.isTrashed; trashedAt = value.trashedAt
    }

    func makeReceipt(matter: ExpenseMatter?) -> Receipt {
        let value = Receipt(id: id, merchant: merchant, transactionDate: transactionDate, currencyCode: currencyCode, subtotal: subtotal, tax: tax, tip: tip, discount: discount, taxLabel: taxLabel, total: total, category: ExpenseCategory(rawValue: categoryRaw) ?? .other, notes: notes, ocrText: ocrText, ocrConfidence: ocrConfidence, reviewStatus: ReceiptReviewStatus(rawValue: reviewStatusRaw) ?? .needsReview, reviewedAt: reviewedAt, validationNotes: validationNotes, fingerprint: fingerprint, paymentMethod: PaymentMethod(rawValue: paymentMethodRaw) ?? .unspecified, reimbursementStatus: ReimbursementStatus(rawValue: reimbursementStatusRaw) ?? .notApplicable, tags: tagsRaw, clientOrCostCentre: clientOrCostCentre, reportingCurrencyCode: reportingCurrencyCode, exchangeRate: exchangeRate, exchangeRateDate: exchangeRateDate, exchangeRateSource: exchangeRateSource, lineItems: lineItems ?? [], fieldConfidence: fieldConfidence ?? .empty, originalEvidenceDigest: originalEvidenceDigest ?? "", currentEvidenceDigest: currentEvidenceDigest ?? "", evidenceSealedAt: evidenceSealedAt, matter: matter)
        value.categoryRaw = categoryRaw
        value.createdAt = createdAt
        value.isTrashed = isTrashed ?? false
        value.trashedAt = trashedAt
        return value
    }
}

private struct RuleRecord: Codable, Sendable {
    let id: UUID; let merchantPattern: String; let categoryRaw: String; let paymentMethodRaw: String; let tags: String; let clientOrCostCentre: String; let matterID: UUID?; let createdAt: Date
    init(_ value: MerchantRule) { id = value.id; merchantPattern = value.merchantPattern; categoryRaw = value.categoryRaw; paymentMethodRaw = value.paymentMethodRaw; tags = value.tags; clientOrCostCentre = value.clientOrCostCentre; matterID = value.matterID; createdAt = value.createdAt }
}

private struct CategoryRecord: Codable, Sendable {
    let id: UUID
    let name: String
    let symbolName: String
    let sortOrder: Int
    let createdAt: Date

    init(_ value: CustomExpenseCategory) {
        id = value.id
        name = value.name
        symbolName = value.symbolName
        sortOrder = value.sortOrder
        createdAt = value.createdAt
    }
}

private struct TombstoneRecord: Codable, Sendable {
    let id: UUID
    let entityID: UUID
    let entityTypeRaw: String
    let deletedAt: Date

    init(_ value: CloudDeletionTombstone) {
        id = value.id
        entityID = value.entityID
        entityTypeRaw = value.entityTypeRaw
        deletedAt = value.deletedAt
    }
}

private extension JSONEncoder {
    static var backupEncoder: JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }
}

private extension JSONDecoder {
    static var backupDecoder: JSONDecoder { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }
}
