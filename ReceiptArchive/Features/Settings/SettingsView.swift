import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        Form {
            Section("Your data") {
                Label("Stored on this device", systemImage: "iphone.and.arrow.forward")
                Text("Receipt images and extracted expense details stay in the app’s private local store. Nothing is uploaded by this version.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Capture & accuracy") {
                Label("Automatic edge detection and crop", systemImage: "viewfinder")
                Label("On-device Apple Vision OCR", systemImage: "text.viewfinder")
                Text("Always compare extracted totals with the original receipt before relying on a report for accounting or tax purposes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Automation") {
                NavigationLink {
                    MerchantRulesView()
                } label: {
                    Label("Merchant rules", systemImage: "wand.and.stars")
                }
                Text("Reuse trusted categories and filing details for merchants you visit regularly.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                NavigationLink("Privacy summary") { PrivacySummaryView() }
                Button("Show onboarding again") { hasCompletedOnboarding = false }
            }
        }
        .navigationTitle("Settings")
    }
}

private struct MerchantRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MerchantRule.merchantPattern) private var rules: [MerchantRule]

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView("No merchant rules", systemImage: "wand.and.stars", description: Text("Add a rule to suggest filing details when a merchant matches."))
            } else {
                ForEach(rules) { rule in
                    NavigationLink { MerchantRuleEditorView(rule: rule) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.merchantPattern).font(.headline)
                            Text([rule.category.rawValue, rule.paymentMethod.rawValue, rule.clientOrCostCentre].filter { !$0.isEmpty && $0 != PaymentMethod.unspecified.rawValue }.joined(separator: " • "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { rules[$0] }.forEach(modelContext.delete)
                    try? modelContext.save()
                }
            }
        }
        .navigationTitle("Merchant rules")
        .toolbar {
            NavigationLink { MerchantRuleEditorView(rule: nil) } label: { Label("Add rule", systemImage: "plus") }
        }
    }
}

private struct MerchantRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    let rule: MerchantRule?
    @State private var merchantPattern: String
    @State private var category: ExpenseCategory
    @State private var paymentMethod: PaymentMethod
    @State private var tags: String
    @State private var clientOrCostCentre: String
    @State private var matterID: UUID?

    init(rule: MerchantRule?) {
        self.rule = rule
        _merchantPattern = State(initialValue: rule?.merchantPattern ?? "")
        _category = State(initialValue: rule?.category ?? .other)
        _paymentMethod = State(initialValue: rule?.paymentMethod ?? .unspecified)
        _tags = State(initialValue: rule?.tags ?? "")
        _clientOrCostCentre = State(initialValue: rule?.clientOrCostCentre ?? "")
        _matterID = State(initialValue: rule?.matterID)
    }

    var body: some View {
        Form {
            Section("Match") {
                TextField("Merchant name contains", text: $merchantPattern)
                Text("Matching ignores capitalization. Use a stable part of the merchant name.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Suggested filing") {
                Picker("Category", selection: $category) { ForEach(ExpenseCategory.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Payment", selection: $paymentMethod) { ForEach(PaymentMethod.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Matter", selection: $matterID) {
                    Text("No suggestion").tag(nil as UUID?)
                    ForEach(matters) { Text($0.name).tag(Optional($0.id)) }
                }
                TextField("Client or cost centre", text: $clientOrCostCentre)
                TextField("Tags, separated by commas", text: $tags)
            }
        }
        .navigationTitle(rule == nil ? "New rule" : "Edit rule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(merchantPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let target = rule ?? MerchantRule(merchantPattern: merchantPattern)
        if rule == nil { modelContext.insert(target) }
        target.merchantPattern = merchantPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        target.category = category
        target.paymentMethod = paymentMethod
        target.matterID = matterID
        target.clientOrCostCentre = clientOrCostCentre.trimmingCharacters(in: .whitespacesAndNewlines)
        target.tags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}

private struct PrivacySummaryView: View {
    var body: some View {
        List {
            Section("Camera") { Text("Used only when you choose to scan a receipt. VisionKit detects the document boundary and crops the image.") }
            Section("Photos") { Text("The system photo picker can import only the images you select; the app does not request broad photo library access.") }
            Section("Files") { Text("The system file picker grants temporary access only to the image or PDF you select. Imported pages are stored inside the app’s private local database.") }
            Section("Sharing") { Text("Exports leave the app only when you choose a destination in Apple’s share sheet.") }
            Section("Collection") { Text("This version includes no accounts, analytics, advertising, tracking, or server upload.") }
        }
        .navigationTitle("Privacy")
    }
}
