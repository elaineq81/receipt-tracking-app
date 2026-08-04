import SwiftData
import SwiftUI

@main
struct ReceiptArchiveApp: App {
    @State private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchases)
                .task { await purchases.start() }
        }
        .modelContainer(for: [ExpenseMatter.self, Receipt.self, ReceiptPage.self, ReceiptRevision.self, MerchantRule.self])
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("deviceLockEnabled") private var deviceLockEnabled = false
    @AppStorage("privacyScreenEnabled") private var privacyScreenEnabled = true
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var authenticationMessage: String?

    var body: some View {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    AppShellView()
                } else {
                    OnboardingView { hasCompletedOnboarding = true }
                }
            }
            .opacity(shouldCover ? 0 : 1)

            if shouldCover {
                VStack(spacing: 18) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 58)).foregroundStyle(.teal)
                    Text("ReceiptSure is locked").font(.title2.bold())
                    if let authenticationMessage { Text(authenticationMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                    if scenePhase == .active && deviceLockEnabled {
                        Button { Task { await unlock() } } label: {
                            if isAuthenticating { ProgressView() } else { Label("Unlock", systemImage: "faceid") }
                        }
                        .buttonStyle(.borderedProminent).tint(.teal).disabled(isAuthenticating)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else {
                if deviceLockEnabled { isUnlocked = false }
                return
            }
            if deviceLockEnabled { await unlock() } else { isUnlocked = true }
        }
        .onChange(of: deviceLockEnabled) { _, enabled in
            if !enabled { isUnlocked = true; authenticationMessage = nil }
            else { isUnlocked = false; Task { await unlock() } }
        }
    }

    private var shouldCover: Bool {
        (privacyScreenEnabled && scenePhase != .active) || (deviceLockEnabled && !isUnlocked)
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            isUnlocked = try await DeviceAuthentication.authenticate()
            authenticationMessage = isUnlocked ? nil : "Authentication was not completed."
        } catch {
            isUnlocked = false
            authenticationMessage = error.localizedDescription
        }
    }
}
