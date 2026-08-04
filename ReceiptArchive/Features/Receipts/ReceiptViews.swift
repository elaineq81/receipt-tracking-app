import PDFKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct ReceiptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.transactionDate, order: .reverse) private var receipts: [Receipt]
    @State private var search = ""
    @State private var scope = ReceiptScope.all
    let scan: () -> Void

    private var filtered: [Receipt] {
        receipts.filter { receipt in
            let matchesScope = scope == .all || (scope == .needsReview ? receipt.reviewStatus == .needsReview : receipt.reviewStatus == .verified)
            let matchesSearch = search.isEmpty || receipt.merchant.localizedCaseInsensitiveContains(search) || receipt.categoryRaw.localizedCaseInsensitiveContains(search) || (receipt.matter?.name.localizedCaseInsensitiveContains(search) ?? false)
            return matchesScope && matchesSearch
        }
    }

    private var attentionReceipts: [Receipt] {
        filtered.sorted {
            if $0.attentionScore == $1.attentionScore { return $0.transactionDate > $1.transactionDate }
            return $0.attentionScore > $1.attentionScore
        }
    }

    var body: some View {
        Group {
            if receipts.isEmpty {
                ContentUnavailableView {
                    Label("No receipts yet", systemImage: "doc.text.viewfinder")
                } description: { Text("Scan a receipt and confirm the extracted figures.") }
                actions: { Button("Scan receipt", action: scan).buttonStyle(.borderedProminent).tint(.teal) }
            } else {
                List {
                    Picker("Receipt status", selection: $scope) {
                        ForEach(ReceiptScope.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    if scope == .needsReview {
                        Section("Highest risk first") {
                            ForEach(attentionReceipts) { receipt in
                                NavigationLink { ReceiptDetailView(receipt: receipt) } label: { ReceiptRow(receipt: receipt) }
                            }
                        }
                    } else {
                        ForEach(Dictionary(grouping: filtered, by: { Calendar.current.startOfDay(for: $0.transactionDate) }).keys.sorted(by: >), id: \.self) { day in
                            Section(day.formatted(date: .complete, time: .omitted)) {
                                ForEach(filtered.filter { Calendar.current.isDate($0.transactionDate, inSameDayAs: day) }) { receipt in
                                    NavigationLink { ReceiptDetailView(receipt: receipt) } label: { ReceiptRow(receipt: receipt) }
                                }
                                .onDelete { offsets in
                                    let rows = filtered.filter { Calendar.current.isDate($0.transactionDate, inSameDayAs: day) }
                                    offsets.map { rows[$0] }.forEach(modelContext.delete)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Receipts")
        .searchable(text: $search, prompt: "Merchant, category, or matter")
        .toolbar { Button("Scan", systemImage: "camera.viewfinder", action: scan) }
    }
}

private enum ReceiptScope: String, CaseIterable, Identifiable {
    case all, needsReview, verified
    var id: String { rawValue }
    var title: String { self == .all ? "All" : (self == .needsReview ? "Attention" : "Verified") }
}

struct ReceiptRow: View {
    let receipt: Receipt
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: receipt.category.symbol)
                .frame(width: 38, height: 38).background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 9)).foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.merchant.isEmpty ? "Unlabeled receipt" : receipt.merchant).font(.headline)
                Text([receipt.category.rawValue, receipt.matter?.name].compactMap { $0 }.joined(separator: " • ")).font(.caption).foregroundStyle(.secondary)
                Label(receipt.reviewStatus.title, systemImage: receipt.reviewStatus.symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(receipt.reviewStatus == .verified ? .green : .orange)
                if receipt.reviewStatus == .needsReview {
                    Text("Risk \(receipt.attentionScore)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(receipt.total.formatted(.currency(code: receipt.currencyCode))).font(.headline)
                Text(receipt.transactionDate, format: .dateTime.day().month(.abbreviated)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var selectedPage = 0
    @State private var editorReceipt: Receipt?

    var body: some View {
        List {
            if !receipt.pages.isEmpty {
                TabView(selection: $selectedPage) {
                    ForEach(receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex })) { page in
                        if let image = UIImage(data: page.imageData) {
                            Image(uiImage: image).resizable().scaledToFit().tag(page.pageIndex)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 360)
                .listRowInsets(EdgeInsets())
            }
            Section("Expense") {
                LabeledContent("Merchant", value: receipt.merchant)
                LabeledContent("Date", value: receipt.transactionDate.formatted(date: .long, time: .omitted))
                LabeledContent("Matter", value: receipt.matter?.name ?? "Unfiled")
                LabeledContent("Category", value: receipt.category.rawValue)
                LabeledContent("Subtotal", value: receipt.subtotal.formatted(.currency(code: receipt.currencyCode)))
                LabeledContent("Tax", value: receipt.tax.formatted(.currency(code: receipt.currencyCode)))
                LabeledContent("Total", value: receipt.total.formatted(.currency(code: receipt.currencyCode))).fontWeight(.semibold)
            }
            Section("Filing") {
                LabeledContent("Payment", value: receipt.paymentMethod.rawValue)
                LabeledContent("Reimbursement", value: receipt.reimbursementStatus.rawValue)
                if !receipt.clientOrCostCentre.isEmpty { LabeledContent("Client / cost centre", value: receipt.clientOrCostCentre) }
                if !receipt.tagsRaw.isEmpty { LabeledContent("Tags", value: receipt.tagsRaw) }
            }
            Section("Evidence status") {
                Label(receipt.reviewStatus.title, systemImage: receipt.reviewStatus.symbol)
                    .foregroundStyle(receipt.reviewStatus == .verified ? .green : .orange)
                LabeledContent("OCR confidence", value: receipt.ocrConfidence.formatted(.percent.precision(.fractionLength(0))))
                if let reviewedAt = receipt.reviewedAt {
                    LabeledContent("Checked", value: reviewedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if !receipt.validationNotes.isEmpty { Text(receipt.validationNotes).font(.footnote).foregroundStyle(.secondary) }
            }
            if !receipt.revisions.isEmpty {
                Section("Revision history") {
                    ForEach(receipt.revisions.sorted(by: { $0.changedAt > $1.changedAt })) { revision in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(revision.fieldName).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(revision.changedAt, format: .dateTime.day().month(.abbreviated).hour().minute()).font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(revision.previousValue) → \(revision.newValue)").font(.footnote)
                            if !revision.reason.isEmpty { Text(revision.reason).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            if !receipt.notes.isEmpty { Section("Notes") { Text(receipt.notes) } }
            if !receipt.ocrText.isEmpty { Section("Recognized text") { Text(receipt.ocrText).font(.caption).textSelection(.enabled) } }
        }
        .navigationTitle(receipt.merchant.isEmpty ? "Receipt" : receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit", systemImage: "pencil") { editorReceipt = receipt }
        }
        .sheet(item: $editorReceipt) { selected in
            NavigationStack { ReceiptEditorView(receipt: selected) }
        }
    }
}

private struct ReceiptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    let receipt: Receipt

    @State private var merchant: String
    @State private var transactionDate: Date
    @State private var selectedMatter: ExpenseMatter?
    @State private var category: ExpenseCategory
    @State private var currencyCode: String
    @State private var subtotal: Decimal
    @State private var tax: Decimal
    @State private var total: Decimal
    @State private var notes: String
    @State private var paymentMethod: PaymentMethod
    @State private var reimbursementStatus: ReimbursementStatus
    @State private var tags: String
    @State private var clientOrCostCentre: String
    @State private var reason = ""
    @State private var confirmedAgainstImage = false

    init(receipt: Receipt) {
        self.receipt = receipt
        _merchant = State(initialValue: receipt.merchant)
        _transactionDate = State(initialValue: receipt.transactionDate)
        _selectedMatter = State(initialValue: receipt.matter)
        _category = State(initialValue: receipt.category)
        _currencyCode = State(initialValue: receipt.currencyCode)
        _subtotal = State(initialValue: receipt.subtotal)
        _tax = State(initialValue: receipt.tax)
        _total = State(initialValue: receipt.total)
        _notes = State(initialValue: receipt.notes)
        _paymentMethod = State(initialValue: receipt.paymentMethod)
        _reimbursementStatus = State(initialValue: receipt.reimbursementStatus)
        _tags = State(initialValue: receipt.tagsRaw)
        _clientOrCostCentre = State(initialValue: receipt.clientOrCostCentre)
    }

    private var warnings: [String] {
        ReceiptEvidence.warnings(merchant: merchant, date: transactionDate, subtotal: subtotal, tax: tax, total: total, currencyCode: currencyCode, ocrConfidence: receipt.ocrConfidence)
    }

    var body: some View {
        Form {
            if let data = receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex }).first?.imageData,
               let image = UIImage(data: data) {
                Section { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).frame(maxWidth: .infinity) }
            }
            Section("Expense details") {
                TextField("Merchant", text: $merchant)
                DatePicker("Date", selection: $transactionDate, displayedComponents: .date)
                Picker("Matter", selection: $selectedMatter) {
                    Text("Unfiled").tag(nil as ExpenseMatter?)
                    ForEach(matters) { Text($0.name).tag(Optional($0)) }
                }
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
                TextField("Currency", text: $currencyCode).textInputAutocapitalization(.characters)
                DecimalField("Subtotal", value: $subtotal)
                DecimalField("Tax", value: $tax)
                DecimalField("Total", value: $total)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            Section("Filing") {
                Picker("Payment", selection: $paymentMethod) { ForEach(PaymentMethod.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Reimbursement", selection: $reimbursementStatus) { ForEach(ReimbursementStatus.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Client or cost centre", text: $clientOrCostCentre)
                TextField("Tags, separated by commas", text: $tags)
            }
            if !warnings.isEmpty {
                Section("Needs attention") {
                    ForEach(warnings, id: \.self) { Label($0, systemImage: "exclamationmark.circle").font(.footnote) }
                }
            }
            Section("Change record") {
                TextField("Reason for changes (optional)", text: $reason, axis: .vertical)
                Toggle("I checked the updated details against the image", isOn: $confirmedAgainstImage)
            }
        }
        .navigationTitle("Edit receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currencyCode.count != 3 || total < 0)
            }
        }
    }

    private func save() {
        record("Merchant", receipt.merchant, merchant)
        record("Date", receipt.transactionDate.formatted(date: .numeric, time: .omitted), transactionDate.formatted(date: .numeric, time: .omitted))
        record("Matter", receipt.matter?.name ?? "Unfiled", selectedMatter?.name ?? "Unfiled")
        record("Category", receipt.category.rawValue, category.rawValue)
        record("Currency", receipt.currencyCode, currencyCode.uppercased())
        record("Subtotal", NSDecimalNumber(decimal: receipt.subtotal).stringValue, NSDecimalNumber(decimal: subtotal).stringValue)
        record("Tax", NSDecimalNumber(decimal: receipt.tax).stringValue, NSDecimalNumber(decimal: tax).stringValue)
        record("Total", NSDecimalNumber(decimal: receipt.total).stringValue, NSDecimalNumber(decimal: total).stringValue)
        record("Notes", receipt.notes, notes)
        record("Payment", receipt.paymentMethod.rawValue, paymentMethod.rawValue)
        record("Reimbursement", receipt.reimbursementStatus.rawValue, reimbursementStatus.rawValue)
        record("Client / cost centre", receipt.clientOrCostCentre, clientOrCostCentre)
        record("Tags", receipt.tagsRaw, tags)

        receipt.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.transactionDate = transactionDate
        receipt.matter = selectedMatter
        receipt.category = category
        receipt.currencyCode = currencyCode.uppercased()
        receipt.subtotal = subtotal
        receipt.tax = tax
        receipt.total = total
        receipt.notes = notes
        receipt.paymentMethod = paymentMethod
        receipt.reimbursementStatus = reimbursementStatus
        receipt.clientOrCostCentre = clientOrCostCentre.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.tagsRaw = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.validationNotes = warnings.joined(separator: "; ")
        receipt.fingerprint = ReceiptEvidence.fingerprint(merchant: merchant, date: transactionDate, total: total, currencyCode: currencyCode)
        receipt.reviewStatus = confirmedAgainstImage ? .verified : .needsReview
        receipt.reviewedAt = confirmedAgainstImage ? .now : nil
        try? modelContext.save()
        dismiss()
    }

    private func record(_ field: String, _ before: String, _ after: String) {
        guard before != after else { return }
        let revision = ReceiptRevision(fieldName: field, previousValue: before, newValue: after, reason: reason, receipt: receipt)
        modelContext.insert(revision)
        receipt.revisions.append(revision)
    }
}

struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let preselectedMatter: ExpenseMatter?
    @State private var images: [UIImage] = []
    @State private var draft = OCRDraft()
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var didCapture = false
    @State private var isShowingCamera = false
    @State private var isImportingFile = false
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        Group {
            if !didCapture {
                if isShowingCamera && VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { result in
                        switch result {
                        case .success(let scanned):
                            images = scanned
                            didCapture = !scanned.isEmpty
                            if !scanned.isEmpty { readReceipt() } else { isShowingCamera = false }
                        case .failure(let error): errorMessage = error.localizedDescription
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 18) {
                        Spacer()
                        Image(systemName: "doc.viewfinder.fill").font(.system(size: 62)).foregroundStyle(.teal)
                        VStack(spacing: 8) {
                            Text("Add a receipt").font(.largeTitle.bold())
                            Text("Scan with automatic cropping, or import an existing image or PDF.")
                                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 28)
                        VStack(spacing: 12) {
                            Button { isShowingCamera = true } label: { Label("Scan with camera", systemImage: "camera.viewfinder").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent).tint(.teal).disabled(!VNDocumentCameraViewController.isSupported)
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                                Label("Choose from Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            Button { isImportingFile = true } label: { Label("Import image or PDF", systemImage: "folder").frame(maxWidth: .infinity) }
                                .buttonStyle(.bordered)
                        }
                        .controlSize(.large).padding(.horizontal, 32)
                        if !VNDocumentCameraViewController.isSupported {
                            Text("Camera scanning is unavailable on this device. Photos and Files still work.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } else if isReading {
                ProgressView("Reading receipt…").controlSize(.large)
            } else {
                ReceiptReviewView(draft: draft, images: images, preselectedMatter: preselectedMatter) { dismiss() }
            }
        }
        .navigationTitle("Add receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var imported: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        imported.append(image)
                    }
                }
                images = imported
                didCapture = !imported.isEmpty
                if !imported.isEmpty { readReceipt() }
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.pdf, .image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let imported = try ReceiptFileImporter.images(from: url)
                images = imported
                didCapture = !imported.isEmpty
                if !imported.isEmpty { readReceipt() }
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Couldn’t read receipt", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Enter manually") { didCapture = true; isReading = false }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private func readReceipt() {
        isReading = true
        Task {
            do { draft = try await ReceiptOCRService().recognize(images: images) }
            catch { errorMessage = error.localizedDescription }
            isReading = false
        }
    }
}

private enum ReceiptImportError: LocalizedError {
    case unsupportedFile
    case emptyPDF

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: "Choose a receipt image or PDF file."
        case .emptyPDF: "The selected PDF does not contain any readable pages."
        }
    }
}

private enum ReceiptFileImporter {
    static func images(from url: URL) throws -> [UIImage] {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url), document.pageCount > 0 else { throw ReceiptImportError.emptyPDF }
            return (0..<min(document.pageCount, 20)).compactMap { index in
                document.page(at: index)?.thumbnail(of: CGSize(width: 1800, height: 2400), for: .mediaBox)
            }
        }
        guard let image = UIImage(contentsOfFile: url.path) else { throw ReceiptImportError.unsupportedFile }
        return [image]
    }
}

struct ReceiptReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    @Query private var existingReceipts: [Receipt]
    @Query(sort: \MerchantRule.createdAt) private var merchantRules: [MerchantRule]
    @State private var draft: OCRDraft
    @State private var selectedMatter: ExpenseMatter?
    @State private var notes = ""
    @State private var paymentMethod = PaymentMethod.unspecified
    @State private var reimbursementStatus = ReimbursementStatus.notApplicable
    @State private var tags = ""
    @State private var clientOrCostCentre = ""
    @State private var appliedRuleID: UUID?
    @State private var confirmedAgainstImage = false
    @State private var showDuplicateAlert = false
    let images: [UIImage]
    let didSave: () -> Void

    private var currentWarnings: [String] {
        ReceiptEvidence.warnings(merchant: draft.merchant, date: draft.date, subtotal: draft.subtotal, tax: draft.tax, total: draft.total, currencyCode: draft.currencyCode, ocrConfidence: draft.confidence)
    }

    private var fingerprint: String {
        ReceiptEvidence.fingerprint(merchant: draft.merchant, date: draft.date, total: draft.total, currencyCode: draft.currencyCode)
    }

    private var matchingRule: MerchantRule? {
        merchantRules.filter { $0.matches(draft.merchant) }.max { $0.merchantPattern.count < $1.merchantPattern.count }
    }

    init(draft: OCRDraft, images: [UIImage], preselectedMatter: ExpenseMatter?, didSave: @escaping () -> Void) {
        self._draft = State(initialValue: draft)
        self._selectedMatter = State(initialValue: preselectedMatter)
        self.images = images
        self.didSave = didSave
    }

    var body: some View {
        Form {
            if let image = images.first {
                Section { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).frame(maxWidth: .infinity) }
            }
            Section {
                HStack {
                    Label(draft.confidence >= 0.85 ? "Strong scan" : "Review recommended", systemImage: draft.confidence >= 0.85 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Spacer()
                    Text(draft.confidence.formatted(.percent.precision(.fractionLength(0)))).fontWeight(.semibold)
                }
                .foregroundStyle(draft.confidence >= 0.85 ? .green : .orange)
                ForEach(currentWarnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.secondary)
                }
            } header: { Text("Scan confidence") } footer: { Text("Confidence describes text recognition quality, not whether an expense is valid.") }
            Section("Check the extracted details") {
                TextField("Merchant", text: $draft.merchant)
                DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                Picker("Matter", selection: $selectedMatter) {
                    Text("Unfiled").tag(nil as ExpenseMatter?)
                    ForEach(matters) { Text($0.name).tag(Optional($0)) }
                }
                Picker("Category", selection: $draft.category) {
                    ForEach(ExpenseCategory.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
                TextField("Currency", text: $draft.currencyCode).textInputAutocapitalization(.characters)
            }
            Section("Figures") {
                DecimalField("Subtotal", value: $draft.subtotal)
                DecimalField("Tax", value: $draft.tax)
                DecimalField("Total", value: $draft.total)
            }
            if let rule = matchingRule, appliedRuleID != rule.id {
                Section("Merchant rule available") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Matches “\(rule.merchantPattern)”").font(.subheadline.weight(.semibold))
                        Text("Apply its category and filing suggestions, then review them before saving.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Apply suggestions") { apply(rule) }
                }
            }
            Section("Filing") {
                Picker("Payment", selection: $paymentMethod) { ForEach(PaymentMethod.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Reimbursement", selection: $reimbursementStatus) { ForEach(ReimbursementStatus.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Client or cost centre", text: $clientOrCostCentre)
                TextField("Tags, separated by commas", text: $tags)
            }
            Section("Notes") { TextField("Optional notes", text: $notes, axis: .vertical) }
            Section("Verification") {
                Toggle("I checked this against the receipt image", isOn: $confirmedAgainstImage)
                Text(confirmedAgainstImage ? "This receipt will be marked Verified." : "You can save it, but it will remain in Needs Review.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Review receipt")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if existingReceipts.contains(where: { $0.fingerprint == fingerprint && !$0.fingerprint.isEmpty }) {
                        showDuplicateAlert = true
                    } else { saveReceipt() }
                }
                .disabled(draft.merchant.trimmingCharacters(in: .whitespaces).isEmpty || draft.total < 0 || draft.currencyCode.count != 3)
            }
        }
        .alert("Possible duplicate", isPresented: $showDuplicateAlert) {
            Button("Save anyway") { saveReceipt() }
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            Text("A receipt with the same merchant, date, currency, and total is already saved.")
        }
    }

    private func saveReceipt() {
        let status: ReceiptReviewStatus = confirmedAgainstImage ? .verified : .needsReview
        let receipt = Receipt(merchant: draft.merchant, transactionDate: draft.date, currencyCode: draft.currencyCode.uppercased(), subtotal: draft.subtotal, tax: draft.tax, total: draft.total, category: draft.category, notes: notes, ocrText: draft.fullText, ocrConfidence: draft.confidence, reviewStatus: status, reviewedAt: confirmedAgainstImage ? .now : nil, validationNotes: currentWarnings.joined(separator: "; "), fingerprint: fingerprint, paymentMethod: paymentMethod, reimbursementStatus: reimbursementStatus, tags: tags.trimmingCharacters(in: .whitespacesAndNewlines), clientOrCostCentre: clientOrCostCentre.trimmingCharacters(in: .whitespacesAndNewlines), matter: selectedMatter)
        modelContext.insert(receipt)
        for (index, image) in images.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.88) {
                let page = ReceiptPage(imageData: data, pageIndex: index)
                modelContext.insert(page)
                receipt.pages.append(page)
            }
        }
        try? modelContext.save()
        didSave()
    }

    private func apply(_ rule: MerchantRule) {
        draft.category = rule.category
        paymentMethod = rule.paymentMethod
        tags = rule.tags
        clientOrCostCentre = rule.clientOrCostCentre
        if let matterID = rule.matterID { selectedMatter = matters.first(where: { $0.id == matterID }) }
        appliedRuleID = rule.id
    }
}

private struct DecimalField: View {
    let title: String
    @Binding var value: Decimal
    init(_ title: String, value: Binding<Decimal>) { self.title = title; self._value = value }
    var body: some View { TextField(title, value: $value, format: .number.precision(.fractionLength(2))).keyboardType(.decimalPad) }
}
