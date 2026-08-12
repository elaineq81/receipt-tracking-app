import Foundation
import SwiftData

enum PersistenceError: LocalizedError {
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            "ReceiptSure could not save this change. Your editor has been kept open so you can try again."
        }
    }

    var recoverySuggestion: String? {
        "Check that the device has available storage, then try again."
    }
}

@MainActor
enum PersistenceService {
    static func delete<T: PersistentModel>(
        _ model: T,
        entityID: UUID,
        entityType: CloudEntityType,
        from modelContext: ModelContext
    ) {
        modelContext.insert(CloudDeletionTombstone(entityID: entityID, entityType: entityType))
        modelContext.delete(model)
    }

    static func save(_ modelContext: ModelContext) throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw PersistenceError.saveFailed(underlying: error)
        }
    }
}
