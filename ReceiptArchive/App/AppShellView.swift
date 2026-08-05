import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case matters, receipts, reports, settings
}

enum SheetDestination: Identifiable {
    case newMatter
    case scan(matter: ExpenseMatter?)
    case paywall(PaywallReason)

    var id: String {
        switch self {
        case .newMatter: "new-matter"
        case .scan: "scan"
        case .paywall(let reason): "paywall-\(reason.id)"
        }
    }
}

struct AppShellView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Query private var matters: [ExpenseMatter]
    @Query private var receipts: [Receipt]
    @State private var selectedTab: AppTab = ScreenshotSupport.requestedTab
    @State private var sheet: SheetDestination?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MattersView(
                    addMatter: requestNewMatter,
                    scan: requestScan
                )
            }
            .tabItem { Label("Matters", systemImage: "folder.fill") }
            .tag(AppTab.matters)

            NavigationStack {
                ReceiptsView(scan: { requestScan(nil) })
            }
            .tabItem { Label("Receipts", systemImage: "doc.text.viewfinder") }
            .tag(AppTab.receipts)

            NavigationStack { ReportsView(presentPaywall: { sheet = .paywall($0) }) }
                .tabItem { Label("Reports", systemImage: "chart.bar.doc.horizontal") }
                .tag(AppTab.reports)

            NavigationStack { SettingsView(presentPaywall: { sheet = .paywall($0) }) }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(.teal)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .newMatter:
                NavigationStack { MatterEditorView() }
            case .scan(let matter):
                NavigationStack { ScanFlowView(preselectedMatter: matter) }
                    .interactiveDismissDisabled()
            case .paywall(let reason):
                PaywallView(reason: reason)
            }
        }
    }

    private func requestNewMatter() {
        if purchases.isPro || matters.count < FreePlanLimits.matters {
            sheet = .newMatter
        } else {
            sheet = .paywall(.matterLimit)
        }
    }

    private func requestScan(_ matter: ExpenseMatter?) {
        if purchases.isPro || receipts.count < FreePlanLimits.receipts {
            sheet = .scan(matter: matter)
        } else {
            sheet = .paywall(.receiptLimit)
        }
    }
}

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let finish: () -> Void
    @State private var page = 0

    private let pages = [
        ("ReceiptSure", "Trusted receipts, tidy reports. Scan it. Check it. Prove it.", "doc.text.viewfinder"),
        ("Accurate by design", "Apple Vision reads key fields on-device. You confirm every figure before it is saved.", "checkmark.seal.fill"),
        ("Reports ready to share", "Create clean PDF, Excel, CSV, Word, or image bundles—with category and currency totals.", "square.and.arrow.up.fill")
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: pages[page].2)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.teal)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : page)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(pages[page].0).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(pages[page].1).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
            Button(page == pages.count - 1 ? "Start organizing" : "Continue") {
                if page == pages.count - 1 {
                    finish()
                } else if reduceMotion {
                    page += 1
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .padding(.bottom, 28)
        }
    }
}
