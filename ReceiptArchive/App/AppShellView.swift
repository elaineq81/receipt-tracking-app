import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case matters, receipts, reports, settings
}

enum SheetDestination: Identifiable {
    case newMatter
    case scan(matter: ExpenseMatter?)

    var id: String {
        switch self {
        case .newMatter: "new-matter"
        case .scan: "scan"
        }
    }
}

struct AppShellView: View {
    @State private var selectedTab: AppTab = .matters
    @State private var sheet: SheetDestination?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MattersView(
                    addMatter: { sheet = .newMatter },
                    scan: { sheet = .scan(matter: $0) }
                )
            }
            .tabItem { Label("Matters", systemImage: "folder.fill") }
            .tag(AppTab.matters)

            NavigationStack {
                ReceiptsView(scan: { sheet = .scan(matter: nil) })
            }
            .tabItem { Label("Receipts", systemImage: "doc.text.viewfinder") }
            .tag(AppTab.receipts)

            NavigationStack { ReportsView() }
                .tabItem { Label("Reports", systemImage: "chart.bar.doc.horizontal") }
                .tag(AppTab.reports)

            NavigationStack { SettingsView() }
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
            }
        }
    }
}

struct OnboardingView: View {
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
                .symbolEffect(.bounce, value: page)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(pages[page].0).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(pages[page].1).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
            Button(page == pages.count - 1 ? "Start organizing" : "Continue") {
                if page == pages.count - 1 { finish() } else { withAnimation { page += 1 } }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .padding(.bottom, 28)
        }
    }
}
