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
        .modelContainer(for: [ExpenseMatter.self, Receipt.self, ReceiptPage.self, ReceiptRevision.self, MerchantRule.self, CustomExpenseCategory.self, CloudDeletionTombstone.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("deviceLockEnabled") private var deviceLockEnabled = false
    @AppStorage("privacyScreenEnabled") private var privacyScreenEnabled = true
    @AppStorage("privateCloudSyncEnabled") private var privateCloudSyncEnabled = false
    @AppStorage("lastPrivateCloudSyncAt") private var lastPrivateCloudSyncAt = 0.0
    @State private var lockState = DeviceLockState()
    @State private var isCloudSyncing = false

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
                    if let authenticationMessage = lockState.authenticationMessage { Text(authenticationMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                    if scenePhase == .active && deviceLockEnabled {
                        Button { requestUnlock() } label: {
                            if lockState.isAuthenticating { ProgressView() } else { Label("Unlock", systemImage: "faceid") }
                        }
                        .buttonStyle(.borderedProminent).tint(.teal).disabled(lockState.isAuthenticating)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
        .task {
            ScreenshotSupport.prepare(modelContext: modelContext)
            handleScenePhase(scenePhase)
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onChange(of: deviceLockEnabled) { _, enabled in
            if enabled {
                lockState.requireAuthentication()
                if scenePhase == .active { requestUnlock() }
            } else {
                lockState.unlockWithoutAuthentication()
            }
        }
    }

    private var shouldCover: Bool {
        (privacyScreenEnabled && scenePhase != .active) || (deviceLockEnabled && !lockState.isUnlocked)
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if deviceLockEnabled { requestUnlock() }
            else { lockState.unlockWithoutAuthentication() }
            requestPrivateCloudSyncIfNeeded()
        case .background:
            if deviceLockEnabled { lockState.lockAfterEnteringBackground() }
        case .inactive:
            // Face ID and system overlays temporarily make the scene inactive.
            // Relocking here cancels or repeats an otherwise successful prompt.
            break
        @unknown default:
            break
        }
    }

    private func requestUnlock() {
        guard deviceLockEnabled, let generation = lockState.beginAuthentication() else { return }
        Task {
            do {
                let authenticated = try await DeviceAuthentication.authenticate()
                lockState.completeAuthentication(
                    succeeded: authenticated,
                    message: nil,
                    generation: generation
                )
            } catch {
                lockState.completeAuthentication(
                    succeeded: false,
                    message: error.localizedDescription,
                    generation: generation
                )
            }
        }
    }

    private func requestPrivateCloudSyncIfNeeded() {
        guard privateCloudSyncEnabled,
              !isCloudSyncing,
              Date.now.timeIntervalSince1970 - lastPrivateCloudSyncAt > 15 * 60 else { return }
        isCloudSyncing = true
        Task {
            defer { isCloudSyncing = false }
            guard let result = try? await PrivateCloudSyncService.sync(modelContext: modelContext) else { return }
            lastPrivateCloudSyncAt = result.completedAt.timeIntervalSince1970
        }
    }
}
