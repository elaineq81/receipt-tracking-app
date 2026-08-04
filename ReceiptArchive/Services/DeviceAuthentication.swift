import Foundation
import LocalAuthentication

enum DeviceAuthentication {
    static func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error { throw error }
            return false
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your private ReceiptSure library")
    }
}
