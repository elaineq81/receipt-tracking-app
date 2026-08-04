import SwiftData
import SwiftUI

@main
struct ReceiptArchiveApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ExpenseMatter.self, Receipt.self, ReceiptPage.self])
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            AppShellView()
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}

