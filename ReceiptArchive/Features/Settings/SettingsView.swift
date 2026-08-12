import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("deviceLockEnabled") private var deviceLockEnabled = false
    @AppStorage("privacyScreenEnabled") private var privacyScreenEnabled = true
    @AppStorage("lastSecureBackupAt") private var lastSecureBackupAt = 0.0
    let presentPaywall: (PaywallReason) -> Void
    @State private var purchaseMessage: String?

    var body: some View {
        Form {
            Section("ReceiptSure Pro") {
                if purchases.isPro {
                    Label("Lifetime Pro is active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.teal)
                    Text("Unlimited receipts, matters, reports, and merchant rules are unlocked on this device.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Button { presentPaywall(.settings) } label: {
                        Label("Unlock Pro — one-time purchase", systemImage: "checkmark.seal")
                    }
                    Text("Keep using the free plan, or upgrade once with no subscription.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Restore Purchases") {
                    Task {
                        if await purchases.restore() {
                            purchaseMessage = "ReceiptSure Pro has been restored."
                        } else {
                            purchaseMessage = purchases.errorMessage
                        }
                    }
                }
                .disabled(purchases.isLoading)
            }
            Section("Your data") {
                Label("Stored on this device", systemImage: "iphone.and.arrow.forward")
                Text("Receipt images and expense details stay local unless you explicitly enable private iCloud sync.")
                    .font(.footnote).foregroundStyle(.secondary)
                NavigationLink {
                    PrivateCloudSyncView()
                } label: {
                    Label("Private iCloud sync", systemImage: "icloud.fill")
                }
            }
            Section("Security & continuity") {
                Toggle(isOn: $deviceLockEnabled) { Label("Require Face ID or passcode", systemImage: "faceid") }
                Toggle(isOn: $privacyScreenEnabled) { Label("Hide content in app switcher", systemImage: "eye.slash.fill") }
                NavigationLink {
                    SecureBackupView()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Encrypted backup & restore", systemImage: "externaldrive.badge.icloud")
                        Text(backupStatus).font(.caption).foregroundStyle(backupStatusColor)
                    }
                }
            }
            Section("Capture & accuracy") {
                Label("Automatic edge detection and crop", systemImage: "viewfinder")
                Label("On-device Apple Vision OCR", systemImage: "text.viewfinder")
                Text("Always compare extracted totals with the original receipt before relying on a report for accounting or tax purposes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Automation") {
                if purchases.isPro {
                    NavigationLink {
                        MerchantRulesView()
                    } label: {
                        Label("Merchant rules", systemImage: "wand.and.stars")
                    }
                } else {
                    Button { presentPaywall(.automation) } label: {
                        HStack {
                            Label("Merchant rules", systemImage: "wand.and.stars")
                            Spacer()
                            Text("PRO").font(.caption.bold()).foregroundStyle(.teal)
                        }
                    }
                }
                Text("Reuse trusted categories and filing details for merchants you visit regularly.")
                    .font(.footnote).foregroundStyle(.secondary)
                NavigationLink {
                    CustomCategoriesView()
                } label: {
                    Label("Custom categories", systemImage: "tag.fill")
                }
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                NavigationLink("Privacy summary") { PrivacySummaryView() }
                Link("Privacy policy", destination: Self.privacyPolicyURL)
                Link("Terms of Use", destination: Self.termsOfUseURL)
                Link("Help & support", destination: Self.supportURL)
                Button("Show onboarding again") { hasCompletedOnboarding = false }
            }
        }
        .navigationTitle("Settings")
        .alert("Purchases", isPresented: Binding(get: { purchaseMessage != nil }, set: { if !$0 { purchaseMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseMessage ?? "Please try again.")
        }
    }

    private static let privacyPolicyURL = URL(string: "https://receipt-tracking-app-lemon.vercel.app/privacy")!
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let supportURL = URL(string: "https://receipt-tracking-app-lemon.vercel.app/support")!

    private var backupStatus: String {
        guard lastSecureBackupAt > 0 else { return "No secure backup created" }
        return "Last backup \(Date(timeIntervalSince1970: lastSecureBackupAt).formatted(.relative(presentation: .named)))"
    }

    private var backupStatusColor: Color {
        guard lastSecureBackupAt > 0 else { return .orange }
        return Date.now.timeIntervalSince1970 - lastSecureBackupAt < 30 * 86_400 ? .green : .orange
    }
}

private struct MerchantRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MerchantRule.merchantPattern) private var rules: [MerchantRule]
    @State private var saveError: String?

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView("No merchant rules", systemImage: "wand.and.stars", description: Text("Add a rule to suggest filing details when a merchant matches."))
            } else {
                ForEach(rules) { rule in
                    NavigationLink { MerchantRuleEditorView(rule: rule) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.merchantPattern).font(.headline)
                            Text([rule.categoryDisplayName, rule.paymentMethod.rawValue, rule.clientOrCostCentre].filter { !$0.isEmpty && $0 != PaymentMethod.unspecified.rawValue }.joined(separator: " • "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { rules[$0] }.forEach {
                        PersistenceService.delete($0, entityID: $0.id, entityType: .merchantRule, from: modelContext)
                    }
                    do {
                        try PersistenceService.save(modelContext)
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            }
        }
        .navigationTitle("Merchant rules")
        .toolbar {
            NavigationLink { MerchantRuleEditorView(rule: nil) } label: { Label("Add rule", systemImage: "plus") }
        }
        .alert("Couldn’t update merchant rules", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }
}

private struct MerchantRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    @Query(sort: \CustomExpenseCategory.sortOrder) private var customCategories: [CustomExpenseCategory]
    let rule: MerchantRule?
    @State private var merchantPattern: String
    @State private var categoryName: String
    @State private var paymentMethod: PaymentMethod
    @State private var tags: String
    @State private var clientOrCostCentre: String
    @State private var matterID: UUID?
    @State private var saveError: String?

    init(rule: MerchantRule?) {
        self.rule = rule
        _merchantPattern = State(initialValue: rule?.merchantPattern ?? "")
        _categoryName = State(initialValue: rule?.categoryDisplayName ?? ExpenseCategory.other.rawValue)
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
                Picker("Category", selection: $categoryName) {
                    ForEach(ExpenseCategoryOption.options(customCategories: customCategories, including: categoryName)) { option in
                        Label(option.displayName, systemImage: option.symbol).tag(option.name)
                    }
                }
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
        .alert("Couldn’t save merchant rule", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func save() {
        let target = rule ?? MerchantRule(merchantPattern: merchantPattern)
        if rule == nil { modelContext.insert(target) }
        target.merchantPattern = merchantPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        target.categoryRaw = categoryName
        target.paymentMethod = paymentMethod
        target.matterID = matterID
        target.clientOrCostCentre = clientOrCostCentre.trimmingCharacters(in: .whitespacesAndNewlines)
        target.tags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        target.updatedAt = .now
        do {
            try PersistenceService.save(modelContext)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct PrivateCloudSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("privateCloudSyncEnabled") private var isEnabled = false
    @AppStorage("lastPrivateCloudSyncAt") private var lastSyncAt = 0.0
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                Toggle("Sync with private iCloud", isOn: $isEnabled)
                if isEnabled {
                    Button {
                        syncNow()
                    } label: {
                        HStack {
                            if isSyncing { ProgressView() }
                            Label("Sync now", systemImage: "arrow.triangle.2.circlepath.icloud")
                        }
                    }
                    .disabled(isSyncing)
                }
            } header: {
                Text("Private sync")
            } footer: {
                Text("When enabled, ReceiptSure uploads an encrypted library snapshot—including receipt images—to your private iCloud database. It is available only to devices signed in to your Apple Account. Sync merges records and honors permanent-deletion markers.")
            }

            Section("Status") {
                if lastSyncAt > 0 {
                    LabeledContent("Last successful sync", value: Date(timeIntervalSince1970: lastSyncAt).formatted(date: .abbreviated, time: .shortened))
                } else {
                    Label("Not synced yet", systemImage: "icloud.slash")
                        .foregroundStyle(.secondary)
                }
                if let statusMessage {
                    Text(statusMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Protection") {
                Label("Private CloudKit database", systemImage: "person.crop.circle.badge.checkmark")
                Label("AES-GCM encrypted snapshot", systemImage: "lock.shield.fill")
                Label("Encryption key synced by iCloud Keychain", systemImage: "key.icloud.fill")
                Text("ReceiptSure does not operate a developer server and cannot browse your private iCloud database through the app.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Button("Delete iCloud copy", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(isSyncing)
            } footer: {
                Text("This removes only ReceiptSure’s encrypted snapshot from your private iCloud database. Receipts on this iPhone remain.")
            }
        }
        .navigationTitle("Private iCloud sync")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isEnabled) { _, enabled in
            if enabled { syncNow() }
        }
        .alert("iCloud sync couldn’t finish", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .confirmationDialog("Delete private iCloud copy?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Cloud Copy", role: .destructive) {
                deleteCloudCopy()
            }
            Button("Keep Copy", role: .cancel) {}
        } message: {
            Text("A different device with private sync still enabled may upload its library again. Local receipts will not be deleted.")
        }
    }

    private func syncNow() {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = nil
        Task {
            do {
                let result = try await PrivateCloudSyncService.sync(modelContext: modelContext)
                lastSyncAt = result.completedAt.timeIntervalSince1970
                let imported = result.downloadedReceipts + result.downloadedMatters + result.downloadedRules + result.downloadedCategories
                statusMessage = imported == 0
                    ? "Your private iCloud library is up to date."
                    : "Merged \(imported) records from your private iCloud library."
            } catch {
                errorMessage = error.localizedDescription
            }
            isSyncing = false
        }
    }

    private func deleteCloudCopy() {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = nil
        Task {
            do {
                try await PrivateCloudSyncService.deleteCloudSnapshot()
                isEnabled = false
                lastSyncAt = 0
                statusMessage = "The private iCloud copy was deleted. Your receipts remain on this iPhone."
            } catch {
                errorMessage = error.localizedDescription
            }
            isSyncing = false
        }
    }
}

private struct CustomCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomExpenseCategory.sortOrder) private var categories: [CustomExpenseCategory]
    @State private var saveError: String?

    var body: some View {
        List {
            Section {
                ForEach(ExpenseCategory.allCases) { category in
                    Label(category.localizedName, systemImage: category.symbol)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Built-in")
            } footer: {
                Text("Built-in categories are always available and cannot be removed.")
            }

            Section {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No custom categories",
                        systemImage: "tag",
                        description: Text("Create categories that match your business, project, or reimbursement workflow.")
                    )
                } else {
                    ForEach(categories) { category in
                        NavigationLink {
                            CustomCategoryEditorView(category: category)
                        } label: {
                            Label(category.name, systemImage: category.symbolName)
                        }
                    }
                    .onDelete(perform: delete)
                }
            } header: {
                Text("Custom")
            } footer: {
                Text("Deleting a category removes it from future pickers. Existing receipts keep their category name for accurate historical reports.")
            }
        }
        .navigationTitle("Custom categories")
        .toolbar {
            NavigationLink {
                CustomCategoryEditorView(category: nil)
            } label: {
                Label("Add category", systemImage: "plus")
            }
        }
        .alert("Couldn’t update categories", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func delete(_ offsets: IndexSet) {
        offsets.map { categories[$0] }.forEach {
            PersistenceService.delete($0, entityID: $0.id, entityType: .customCategory, from: modelContext)
        }
        do {
            try PersistenceService.save(modelContext)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct CustomCategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [CustomExpenseCategory]
    @Query private var receipts: [Receipt]
    @Query private var rules: [MerchantRule]
    let category: CustomExpenseCategory?
    @State private var name: String
    @State private var symbolName: String
    @State private var saveError: String?

    private let symbols = [
        "tag.fill", "briefcase.fill", "building.2.fill", "airplane", "tram.fill",
        "cart.fill", "wrench.and.screwdriver.fill", "gift.fill", "heart.fill", "graduationcap.fill"
    ]

    init(category: CustomExpenseCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _symbolName = State(initialValue: category?.symbolName ?? "tag.fill")
    }

    var body: some View {
        Form {
            Section("Category") {
                TextField("Category name", text: $name)
                    .textInputAutocapitalization(.words)
                Picker("Icon", selection: $symbolName) {
                    ForEach(symbols, id: \.self) { symbol in
                        Label(symbol.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " ").capitalized, systemImage: symbol)
                            .tag(symbol)
                    }
                }
            }
            if category != nil {
                Section {
                    Text("Renaming updates existing receipts and merchant rules that use this custom category, preserving consistent reports.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(category == nil ? "New category" : "Edit category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Couldn’t save category", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func save() {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let conflictsWithBuiltIn = ExpenseCategory.allCases.contains { $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame }
        let conflictsWithCustom = categories.contains {
            $0.id != category?.id && $0.name.caseInsensitiveCompare(normalized) == .orderedSame
        }
        guard !conflictsWithBuiltIn, !conflictsWithCustom else {
            saveError = "Choose a category name that is not already in use."
            return
        }

        if let category {
            let updatedAt = Date.now
            let oldName = category.name
            category.name = normalized
            category.symbolName = symbolName
            category.updatedAt = updatedAt
            receipts.filter { $0.categoryRaw.caseInsensitiveCompare(oldName) == .orderedSame }.forEach {
                $0.categoryRaw = normalized
                $0.updatedAt = updatedAt
            }
            rules.filter { $0.categoryRaw.caseInsensitiveCompare(oldName) == .orderedSame }.forEach {
                $0.categoryRaw = normalized
                $0.updatedAt = updatedAt
            }
        } else {
            modelContext.insert(CustomExpenseCategory(name: normalized, symbolName: symbolName, sortOrder: categories.count))
        }

        do {
            try PersistenceService.save(modelContext)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct PrivacySummaryView: View {
    var body: some View {
        List {
            Section("Camera") { Text("Used only when you choose to scan a receipt. VisionKit detects the document boundary and crops the image.") }
            Section("Photos") { Text("The system photo picker can import only the images you select; the app does not request broad photo library access.") }
            Section("Files") { Text("The system file picker grants temporary access only to the image or PDF you select. Imported pages are stored inside the app’s private local database.") }
            Section("Protection") { Text("Optional device authentication uses Face ID, Touch ID, or the device passcode. Privacy shielding hides receipt content when the app is not active.") }
            Section("Backups") { Text("Secure archives are encrypted locally with AES-GCM and a password-derived key. The password is never stored or uploaded, and restore only adds missing records.") }
            Section("Private iCloud sync") { Text("Off by default. If enabled, an AES-GCM encrypted library snapshot and receipt images are stored in your private CloudKit database. The encryption key uses iCloud Keychain so your signed-in devices can decrypt the snapshot.") }
            Section("Sharing") { Text("Exports leave the app only when you choose a destination in Apple’s share sheet.") }
            Section("Collection") { Text("ReceiptSure includes no developer account, analytics, advertising, or tracking. The developer does not receive your private iCloud content.") }
        }
        .navigationTitle("Privacy")
    }
}
