import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let receiptArchiveBackup = UTType(exportedAs: "com.bodywiseremedy.receiptarchive.backup")
}

struct SecureBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var receipts: [Receipt]
    @Query private var matters: [ExpenseMatter]
    @Query private var rules: [MerchantRule]
    @AppStorage("lastSecureBackupAt") private var lastSecureBackupAt = 0.0
    @AppStorage("lastSecureRestoreAt") private var lastSecureRestoreAt = 0.0

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var isImporting = false
    @State private var shareItem: ShareItem?
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Backup health") {
                LabeledContent("Receipts", value: "\(receipts.count)")
                LabeledContent("Matters", value: "\(matters.count)")
                LabeledContent("Merchant rules", value: "\(rules.count)")
                Label(healthTitle, systemImage: healthSymbol).foregroundStyle(healthColor)
                if lastSecureRestoreAt > 0 {
                    LabeledContent("Last restore", value: Date(timeIntervalSince1970: lastSecureRestoreAt).formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Backup password") {
                SecureField("At least 8 characters", text: $password)
                    .textContentType(.newPassword)
                SecureField("Confirm for new backup", text: $confirmation)
                    .textContentType(.newPassword)
                Text("The password is never stored. Keep it somewhere safe—an archive cannot be restored without it.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Create encrypted archive") {
                Button { createBackup() } label: {
                    HStack {
                        if isWorking { ProgressView() }
                        Label("Create & share backup", systemImage: "lock.doc")
                    }
                }
                .disabled(isWorking || password.count < 8 || password != confirmation)
                Text("Includes receipt images, OCR data, matters, revisions, financial provenance, and merchant rules.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Restore") {
                Button { isImporting = true } label: { Label("Choose encrypted backup", systemImage: "square.and.arrow.down") }
                    .disabled(isWorking || password.count < 8)
                Text("Restore merges missing records and skips receipt IDs already on this device. It never deletes the current library.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backup & restore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.receiptArchiveBackup, .data]) { result in
            do {
                let url = try result.get()
                restore(from: url)
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Backup complete", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(resultMessage ?? "") }
        .alert("Secure archive error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private var healthTitle: String {
        guard lastSecureBackupAt > 0 else { return "Backup recommended" }
        let age = Date.now.timeIntervalSince1970 - lastSecureBackupAt
        return age < 30 * 86_400 ? "Backup is current" : "Backup is over 30 days old"
    }

    private var healthSymbol: String { lastSecureBackupAt > 0 && Date.now.timeIntervalSince1970 - lastSecureBackupAt < 30 * 86_400 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill" }
    private var healthColor: Color { lastSecureBackupAt > 0 && Date.now.timeIntervalSince1970 - lastSecureBackupAt < 30 * 86_400 ? .green : .orange }

    private func createBackup() {
        isWorking = true
        Task {
            do {
                let url = try await SecureBackupService.create(modelContext: modelContext, password: password)
                lastSecureBackupAt = Date.now.timeIntervalSince1970
                shareItem = ShareItem(url: url)
            } catch { errorMessage = error.localizedDescription }
            isWorking = false
        }
    }

    private func restore(from url: URL) {
        isWorking = true
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let summary = try await SecureBackupService.restore(from: url, modelContext: modelContext, password: password)
                lastSecureRestoreAt = Date.now.timeIntervalSince1970
                resultMessage = "Added \(summary.receipts) receipts, \(summary.matters) matters, and \(summary.rules) rules. Skipped \(summary.skippedReceipts) receipts already present."
            } catch { errorMessage = error.localizedDescription }
            isWorking = false
        }
    }
}
