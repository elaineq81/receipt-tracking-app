import CloudKit
import Foundation
import Security
import SwiftData

enum PrivateCloudSyncError: LocalizedError {
    case noAccount
    case restricted
    case temporarilyUnavailable
    case keychain(OSStatus)
    case missingSnapshot

    var errorDescription: String? {
        switch self {
        case .noAccount: "Sign in to iCloud on this iPhone to use private sync."
        case .restricted: "iCloud access is restricted on this device."
        case .temporarilyUnavailable: "Private iCloud sync is temporarily unavailable. Try again later."
        case .keychain: "ReceiptSure could not access its end-to-end encryption key in iCloud Keychain."
        case .missingSnapshot: "The private iCloud snapshot could not be read."
        }
    }
}

struct PrivateCloudSyncResult: Sendable {
    let downloadedReceipts: Int
    let downloadedMatters: Int
    let downloadedRules: Int
    let downloadedCategories: Int
    let completedAt: Date
}

@MainActor
enum PrivateCloudSyncService {
    static let containerIdentifier = "iCloud.com.bodywiseremedy.receiptsure"
    private static let recordID = CKRecord.ID(recordName: "ReceiptSurePrivateLibrary")
    private static let recordType = "ReceiptSurePrivateLibrary"
    private static let assetField = "encryptedSnapshot"

    static func accountStatus() async throws -> CKAccountStatus {
        try await CKContainer(identifier: containerIdentifier).accountStatus()
    }

    static func sync(modelContext: ModelContext) async throws -> PrivateCloudSyncResult {
        let container = CKContainer(identifier: containerIdentifier)
        switch try await container.accountStatus() {
        case .available: break
        case .noAccount: throw PrivateCloudSyncError.noAccount
        case .restricted: throw PrivateCloudSyncError.restricted
        case .couldNotDetermine, .temporarilyUnavailable: throw PrivateCloudSyncError.temporarilyUnavailable
        @unknown default: throw PrivateCloudSyncError.temporarilyUnavailable
        }

        let keyData = try PrivateCloudKeychain.loadOrCreateKey()
        let database = container.privateCloudDatabase
        var record = try await fetchRecordIfPresent(in: database) ?? CKRecord(recordType: recordType, recordID: recordID)
        var summary = RestoreSummary(matters: 0, receipts: 0, rules: 0, categories: 0, skippedReceipts: 0)

        if let data = try snapshotData(from: record) {
            summary = try await SecureBackupService.mergePrivateCloudSnapshot(data, modelContext: modelContext, keyData: keyData)
        }

        do {
            try await uploadCurrentLibrary(to: record, database: database, modelContext: modelContext, keyData: keyData)
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let serverRecord = error.serverRecord else { throw error }
            record = serverRecord
            if let data = try snapshotData(from: record) {
                let retrySummary = try await SecureBackupService.mergePrivateCloudSnapshot(data, modelContext: modelContext, keyData: keyData)
                summary = RestoreSummary(
                    matters: summary.matters + retrySummary.matters,
                    receipts: summary.receipts + retrySummary.receipts,
                    rules: summary.rules + retrySummary.rules,
                    categories: summary.categories + retrySummary.categories,
                    skippedReceipts: summary.skippedReceipts + retrySummary.skippedReceipts
                )
            }
            try await uploadCurrentLibrary(to: record, database: database, modelContext: modelContext, keyData: keyData)
        }

        return PrivateCloudSyncResult(
            downloadedReceipts: summary.receipts,
            downloadedMatters: summary.matters,
            downloadedRules: summary.rules,
            downloadedCategories: summary.categories,
            completedAt: .now
        )
    }

    private static func fetchRecordIfPresent(in database: CKDatabase) async throws -> CKRecord? {
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private static func snapshotData(from record: CKRecord) throws -> Data? {
        guard let asset = record[assetField] as? CKAsset else { return nil }
        guard let url = asset.fileURL else { throw PrivateCloudSyncError.missingSnapshot }
        return try Data(contentsOf: url)
    }

    private static func uploadCurrentLibrary(
        to record: CKRecord,
        database: CKDatabase,
        modelContext: ModelContext,
        keyData: Data
    ) async throws {
        let data = try await SecureBackupService.createPrivateCloudSnapshot(modelContext: modelContext, keyData: keyData)
        let folder = FileManager.default.temporaryDirectory.appending(path: "ReceiptSure-Cloud-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "library.rcloud")
        try data.write(to: url, options: .atomic)

        record[assetField] = CKAsset(fileURL: url)
        record["schemaVersion"] = 4 as CKRecordValue
        record["updatedAt"] = Date.now as CKRecordValue
        record["deviceID"] = cloudDeviceID as CKRecordValue
        _ = try await database.save(record)
    }

    private static var cloudDeviceID: String {
        let key = "privateCloudDeviceID"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}

private enum PrivateCloudKeychain {
    private static let service = "com.bodywiseremedy.receiptsure.private-cloud"
    private static let account = "snapshot-encryption-key-v1"

    static func loadOrCreateKey() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, data.count == 32 { return data }
        guard status == errSecItemNotFound else { throw PrivateCloudSyncError.keychain(status) }

        var key = Data(count: 32)
        let randomStatus = key.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw PrivateCloudSyncError.keychain(randomStatus) }

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: key
        ]
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus == errSecDuplicateItem { return try loadOrCreateKey() }
        guard addStatus == errSecSuccess else { throw PrivateCloudSyncError.keychain(addStatus) }
        return key
    }
}
