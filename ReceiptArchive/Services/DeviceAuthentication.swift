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

struct DeviceLockState {
    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false
    private(set) var authenticationMessage: String?
    private(set) var generation = 0

    mutating func unlockWithoutAuthentication() {
        generation &+= 1
        isUnlocked = true
        isAuthenticating = false
        authenticationMessage = nil
    }

    mutating func requireAuthentication() {
        generation &+= 1
        isUnlocked = false
        isAuthenticating = false
        authenticationMessage = nil
    }

    mutating func lockAfterEnteringBackground() {
        generation &+= 1
        isUnlocked = false
        isAuthenticating = false
        authenticationMessage = nil
    }

    mutating func beginAuthentication() -> Int? {
        guard !isAuthenticating, !isUnlocked else { return nil }
        isAuthenticating = true
        authenticationMessage = nil
        return generation
    }

    mutating func completeAuthentication(
        succeeded: Bool,
        message: String?,
        generation attemptGeneration: Int
    ) {
        guard attemptGeneration == generation else { return }
        isAuthenticating = false
        isUnlocked = succeeded
        authenticationMessage = succeeded ? nil : (message ?? "Authentication was not completed.")
    }
}
