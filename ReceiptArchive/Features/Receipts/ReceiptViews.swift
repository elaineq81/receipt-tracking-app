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
    @State private var pendingTrash: [Receipt] = []
    @State private var persistenceError: String?
    let scan: () -> Void

    private var activeReceipts: [Receipt] { receipts.filter { !$0.isTrashed } }

    private var filtered: [Receipt] {
        activeReceipts.filter { receipt in
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

    private var daySections: [ReceiptDaySection] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.transactionDate) }
            .map { ReceiptDaySection(day: $0.key, receipts: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        Group {
            if activeReceipts.isEmpty {
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
                            .onDelete { pendingTrash = $0.map { attentionReceipts[$0] } }
                        }
                    } else {
                        ForEach(daySections) { section in
                            Section(section.day.formatted(date: .complete, time: .omitted)) {
                                ForEach(section.receipts) { receipt in
                                    NavigationLink { ReceiptDetailView(receipt: receipt) } label: { ReceiptRow(receipt: receipt) }
                                }
                                .onDelete { offsets in
                                    pendingTrash = offsets.map { section.receipts[$0] }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Receipts")
        .searchable(text: $search, prompt: "Merchant, category, or matter")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    RecentlyDeletedReceiptsView()
                } label: {
                    Label("Recently Deleted", systemImage: "trash")
                }
                Button("Scan", systemImage: "camera.viewfinder", action: scan)
            }
        }
        .confirmationDialog(
            "Move \(pendingTrash.count == 1 ? "receipt" : "receipts") to Recently Deleted?",
            isPresented: Binding(get: { !pendingTrash.isEmpty }, set: { if !$0 { pendingTrash = [] } }),
            titleVisibility: .visible
        ) {
            Button("Move to Recently Deleted", role: .destructive) { movePendingToTrash() }
            Button("Cancel", role: .cancel) { pendingTrash = [] }
        } message: {
            Text("You can restore \(pendingTrash.count == 1 ? "it" : "them") later.")
        }
        .alert("Couldn’t update receipts", isPresented: Binding(get: { persistenceError != nil }, set: { if !$0 { persistenceError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "Please try again.")
        }
    }

    private func movePendingToTrash() {
        let receipts = pendingTrash
        pendingTrash = []
        receipts.forEach { $0.moveToTrash() }
        do {
            try PersistenceService.save(modelContext)
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}

private struct RecentlyDeletedReceiptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.trashedAt, order: .reverse) private var receipts: [Receipt]
    @State private var pendingPermanentDelete: Receipt?
    @State private var persistenceError: String?

    private var trashedReceipts: [Receipt] { receipts.filter(\.isTrashed) }

    var body: some View {
        List {
            if trashedReceipts.isEmpty {
                ContentUnavailableView("Recently Deleted is empty", systemImage: "trash", description: Text("Receipts moved here can be restored or deleted permanently."))
            } else {
                ForEach(trashedReceipts) { receipt in
                    ReceiptRow(receipt: receipt)
                        .swipeActions(edge: .leading) {
                            Button("Restore", systemImage: "arrow.uturn.backward") { restore(receipt) }
                                .tint(.teal)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete permanently", systemImage: "trash", role: .destructive) {
                                pendingPermanentDelete = receipt
                            }
                        }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .confirmationDialog(
            "Delete this receipt permanently?",
            isPresented: Binding(get: { pendingPermanentDelete != nil }, set: { if !$0 { pendingPermanentDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) { permanentlyDelete() }
            Button("Cancel", role: .cancel) { pendingPermanentDelete = nil }
        } message: {
            Text("The receipt image and audit history cannot be recovered after this action.")
        }
        .alert("Couldn’t update receipt", isPresented: Binding(get: { persistenceError != nil }, set: { if !$0 { persistenceError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "Please try again.")
        }
    }

    private func restore(_ receipt: Receipt) {
        receipt.restoreFromTrash()
        save()
    }

    private func permanentlyDelete() {
        guard let receipt = pendingPermanentDelete else { return }
        pendingPermanentDelete = nil
        PersistenceService.delete(receipt, entityID: receipt.id, entityType: .receipt, from: modelContext)
        save()
    }

    private func save() {
        do {
            try PersistenceService.save(modelContext)
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}

private struct ReceiptDaySection: Identifiable {
    let day: Date
    let receipts: [Receipt]
    var id: Date { day }
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
                Text([receipt.categoryLocalizedName, receipt.matter?.name].compactMap { $0 }.joined(separator: " • ")).font(.caption).foregroundStyle(.secondary)
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
    @Environment(\.modelContext) private var modelContext
    let receipt: Receipt
    @State private var selectedPage = 0
    @State private var editorReceipt: Receipt?
    @State private var cropPage: ReceiptPage?
    @State private var sharePayload: ReceiptSharePayload?
    @State private var shareError: String?
    @State private var persistenceError: String?
    @State private var isPreparingShare = false
    @State private var integrityStatus = EvidenceIntegrityStatus.notSealed

    var body: some View {
        List {
            if !receipt.pages.isEmpty {
                TabView(selection: $selectedPage) {
                    ForEach(receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex })) { page in
                        StoredReceiptImage(
                            data: page.imageData,
                            cacheKey: "\(page.id.uuidString)-\(receipt.currentEvidenceDigest)",
                            maxPixelSize: 1_400
                        )
                        .tag(page.pageIndex)
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
                LabeledContent("Category", value: receipt.categoryLocalizedName)
                LabeledContent("Subtotal", value: receipt.subtotal.formatted(.currency(code: receipt.currencyCode)))
                LabeledContent(receipt.taxLabel, value: receipt.tax.formatted(.currency(code: receipt.currencyCode)))
                if receipt.tip != 0 { LabeledContent("Tip", value: receipt.tip.formatted(.currency(code: receipt.currencyCode))) }
                if receipt.discount != 0 { LabeledContent("Discount", value: receipt.discount.formatted(.currency(code: receipt.currencyCode))) }
                LabeledContent("Total", value: receipt.total.formatted(.currency(code: receipt.currencyCode))).fontWeight(.semibold)
                let difference = NSDecimalNumber(decimal: receipt.reconciliationDifference).doubleValue
                Label(abs(difference) <= 0.02 ? "Figures reconcile" : "Figures differ by \(receipt.reconciliationDifference.formatted(.currency(code: receipt.currencyCode)))", systemImage: abs(difference) <= 0.02 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(abs(difference) <= 0.02 ? .green : .orange)
            }
            if !receipt.lineItems.isEmpty {
                Section("Line items") {
                    ForEach(receipt.lineItems) { item in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.description)
                                if item.quantity != 1 {
                                    Text("\(NSDecimalNumber(decimal: item.quantity).stringValue) × \(item.unitPrice.formatted(.currency(code: receipt.currencyCode)))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(item.total.formatted(.currency(code: receipt.currencyCode))).fontWeight(.medium)
                        }
                    }
                    LabeledContent("Detected item total", value: receipt.lineItemTotal.formatted(.currency(code: receipt.currencyCode)))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Filing") {
                LabeledContent("Payment", value: receipt.paymentMethod.rawValue)
                LabeledContent("Reimbursement", value: receipt.reimbursementStatus.rawValue)
                if !receipt.clientOrCostCentre.isEmpty { LabeledContent("Client / cost centre", value: receipt.clientOrCostCentre) }
                if !receipt.tagsRaw.isEmpty { LabeledContent("Tags", value: receipt.tagsRaw) }
            }
            if !receipt.reportingCurrencyCode.isEmpty || receipt.exchangeRate > 0 {
                Section("Currency conversion") {
                    if let converted = receipt.reportingTotal {
                        LabeledContent("Reporting total", value: converted.formatted(.currency(code: receipt.reportingCurrencyCode)))
                    } else {
                        Label("Conversion provenance incomplete", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    LabeledContent("Rate", value: NSDecimalNumber(decimal: receipt.exchangeRate).stringValue)
                    if let date = receipt.exchangeRateDate { LabeledContent("Effective date", value: date.formatted(date: .long, time: .omitted)) }
                    if !receipt.exchangeRateSource.isEmpty { LabeledContent("Source", value: receipt.exchangeRateSource) }
                }
            }
            Section("Evidence status") {
                Label(receipt.reviewStatus.title, systemImage: receipt.reviewStatus.symbol)
                    .foregroundStyle(receipt.reviewStatus == .verified ? .green : .orange)
                LabeledContent("OCR confidence", value: receipt.ocrConfidence.formatted(.percent.precision(.fractionLength(0))))
                Label(integrityStatus.title, systemImage: integrityStatus.symbol)
                    .foregroundStyle(integrityStatus == .verified ? .green : .orange)
                if !receipt.originalEvidenceDigest.isEmpty {
                    LabeledContent("Original seal", value: String(receipt.originalEvidenceDigest.prefix(12)).uppercased())
                        .font(.caption).monospaced()
                }
                if let sealedAt = receipt.evidenceSealedAt {
                    LabeledContent("Sealed", value: sealedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let reviewedAt = receipt.reviewedAt {
                    LabeledContent("Checked", value: reviewedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if !receipt.validationNotes.isEmpty { Text(receipt.validationNotes).font(.footnote).foregroundStyle(.secondary) }
            }
            if receipt.fieldConfidence != .empty {
                Section("Field confidence") {
                    ConfidenceRow(title: "Merchant", value: receipt.fieldConfidence.merchant)
                    ConfidenceRow(title: "Date", value: receipt.fieldConfidence.date)
                    ConfidenceRow(title: "Currency", value: receipt.fieldConfidence.currency)
                    ConfidenceRow(title: "Subtotal", value: receipt.fieldConfidence.subtotal)
                    ConfidenceRow(title: receipt.taxLabel, value: receipt.fieldConfidence.tax)
                    ConfidenceRow(title: "Total", value: receipt.fieldConfidence.total)
                    if !receipt.lineItems.isEmpty { ConfidenceRow(title: "Line items", value: receipt.fieldConfidence.lineItems) }
                }
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
            Menu("Share receipt", systemImage: "square.and.arrow.up") {
                Button("PDF with details", systemImage: "doc.richtext") { sharePDF() }
                Button("Receipt images", systemImage: "photo.on.rectangle") { shareImages() }
                    .disabled(receipt.pages.isEmpty)
                Button("Text summary", systemImage: "text.quote") { shareSummary() }
            }
            .disabled(isPreparingShare)

            Menu("Receipt actions", systemImage: "ellipsis.circle") {
                if let page = receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex }).first(where: { $0.pageIndex == selectedPage }) {
                    Button("Adjust crop", systemImage: "crop") { cropPage = page }
                }
                if integrityStatus != .verified {
                    Button("Seal current evidence", systemImage: "checkmark.shield") { sealEvidence() }
                }
                Button("Edit receipt", systemImage: "pencil") { editorReceipt = receipt }
            }
        }
        .sheet(item: $editorReceipt) { selected in
            NavigationStack { ReceiptEditorView(receipt: selected) }
        }
        .sheet(item: $cropPage) { page in
            if let image = UIImage(data: page.imageData) {
                ReceiptCropEditor(image: image, pageNumber: page.pageIndex + 1) { cropped in
                    guard let data = cropped.jpegData(compressionQuality: 0.9) else { return }
                    if page.originalImageData == nil { page.originalImageData = page.imageData }
                    page.imageData = data
                    let revision = ReceiptRevision(
                        fieldName: "Receipt image",
                        previousValue: "Previous crop",
                        newValue: "Adjusted crop",
                        reason: "Receipt edges corrected",
                        receipt: receipt
                    )
                    modelContext.insert(revision)
                    receipt.revisions.append(revision)
                    receipt.reviewStatus = .needsReview
                    receipt.reviewedAt = nil
                    let cropWarning = "Receipt image was recropped; check the extracted details"
                    if !receipt.validationMessages.contains(cropWarning) {
                        receipt.validationNotes = ([cropWarning] + receipt.validationMessages).joined(separator: "; ")
                    }
                    EvidenceIntegrityService.seal(receipt)
                    integrityStatus = .verified
                    saveReceiptChange()
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .alert("Couldn’t share receipt", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError ?? "Please try again.")
        }
        .alert("Couldn’t save receipt", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "Please try again.")
        }
        .task(id: receipt.currentEvidenceDigest) {
            integrityStatus = EvidenceIntegrityService.verify(receipt)
        }
    }

    private var shareTitle: String {
        let merchant = receipt.merchant.isEmpty ? "Receipt" : receipt.merchant
        return "\(merchant) · \(receipt.transactionDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var shareSummaryText: String {
        var lines = [
            shareTitle,
            "Total: \(receipt.total.formatted(.currency(code: receipt.currencyCode)))",
            "Category: \(receipt.categoryDisplayName)",
            "Matter: \(receipt.matter?.name ?? "Unfiled")",
            "Status: \(receipt.reviewStatus.title)"
        ]
        if receipt.tax != 0 {
            lines.insert("\(receipt.taxLabel): \(receipt.tax.formatted(.currency(code: receipt.currencyCode)))", at: 2)
        }
        return lines.joined(separator: "\n")
    }

    private func sharePDF() {
        prepareShare {
            let url = try await ExportService().create(format: .pdf, receipts: [receipt], title: shareTitle)
            return [url as Any, shareSummaryText as Any]
        }
    }

    private func shareImages() {
        prepareShare {
            let urls = try await ExportService().createReceiptImageFiles(receipt: receipt)
            return [shareSummaryText as Any] + urls.map { $0 as Any }
        }
    }

    private func shareSummary() {
        sharePayload = ReceiptSharePayload(items: [shareSummaryText])
    }

    private func prepareShare(_ createItems: @escaping () async throws -> [Any]) {
        isPreparingShare = true
        Task {
            defer { isPreparingShare = false }
            do {
                sharePayload = ReceiptSharePayload(items: try await createItems())
            } catch {
                shareError = error.localizedDescription
            }
        }
    }

    private func sealEvidence() {
        EvidenceIntegrityService.seal(receipt)
        integrityStatus = .verified
        saveReceiptChange()
    }

    private func saveReceiptChange() {
        receipt.updatedAt = .now
        do {
            try PersistenceService.save(modelContext)
        } catch {
            integrityStatus = EvidenceIntegrityService.verify(receipt)
            persistenceError = error.localizedDescription
        }
    }
}

private struct ReceiptSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ConfidenceRow: View {
    let title: String
    let value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            ProgressView(value: max(0, min(1, value)))
                .frame(width: 90)
                .tint(value >= 0.85 ? .green : value >= 0.65 ? .orange : .red)
            Text(value.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) confidence \(value.formatted(.percent.precision(.fractionLength(0))))")
    }
}

private struct ReceiptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    @Query(sort: \CustomExpenseCategory.sortOrder) private var customCategories: [CustomExpenseCategory]
    let receipt: Receipt

    @State private var merchant: String
    @State private var transactionDate: Date
    @State private var selectedMatter: ExpenseMatter?
    @State private var categoryName: String
    @State private var currencyCode: String
    @State private var subtotal: Decimal
    @State private var tax: Decimal
    @State private var tip: Decimal
    @State private var discount: Decimal
    @State private var taxLabel: String
    @State private var total: Decimal
    @State private var notes: String
    @State private var paymentMethod: PaymentMethod
    @State private var reimbursementStatus: ReimbursementStatus
    @State private var tags: String
    @State private var clientOrCostCentre: String
    @State private var reportingCurrencyCode: String
    @State private var exchangeRate: Decimal
    @State private var exchangeRateDate: Date
    @State private var exchangeRateSource: String
    @State private var includesConversion: Bool
    @State private var lineItems: [ReceiptLineItem]
    @State private var reason = ""
    @State private var confirmedAgainstImage = false
    @State private var saveError: String?

    init(receipt: Receipt) {
        self.receipt = receipt
        _merchant = State(initialValue: receipt.merchant)
        _transactionDate = State(initialValue: receipt.transactionDate)
        _selectedMatter = State(initialValue: receipt.matter)
        _categoryName = State(initialValue: receipt.categoryDisplayName)
        _currencyCode = State(initialValue: receipt.currencyCode)
        _subtotal = State(initialValue: receipt.subtotal)
        _tax = State(initialValue: receipt.tax)
        _tip = State(initialValue: receipt.tip)
        _discount = State(initialValue: receipt.discount)
        _taxLabel = State(initialValue: receipt.taxLabel)
        _total = State(initialValue: receipt.total)
        _notes = State(initialValue: receipt.notes)
        _paymentMethod = State(initialValue: receipt.paymentMethod)
        _reimbursementStatus = State(initialValue: receipt.reimbursementStatus)
        _tags = State(initialValue: receipt.tagsRaw)
        _clientOrCostCentre = State(initialValue: receipt.clientOrCostCentre)
        _reportingCurrencyCode = State(initialValue: receipt.reportingCurrencyCode)
        _exchangeRate = State(initialValue: receipt.exchangeRate)
        _exchangeRateDate = State(initialValue: receipt.exchangeRateDate ?? receipt.transactionDate)
        _exchangeRateSource = State(initialValue: receipt.exchangeRateSource)
        _includesConversion = State(initialValue: !receipt.reportingCurrencyCode.isEmpty || receipt.exchangeRate > 0)
        _lineItems = State(initialValue: receipt.lineItems)
    }

    private var warnings: [String] {
        ReceiptEvidence.warnings(merchant: merchant, date: transactionDate, subtotal: subtotal, tax: tax, tip: tip, discount: discount, total: total, currencyCode: currencyCode, ocrConfidence: receipt.ocrConfidence, reportingCurrencyCode: includesConversion ? reportingCurrencyCode : "", exchangeRate: includesConversion ? exchangeRate : 0, exchangeRateDate: includesConversion ? exchangeRateDate : nil, exchangeRateSource: includesConversion ? exchangeRateSource : "")
    }

    var body: some View {
        Form {
            if let page = receipt.pages.sorted(by: { $0.pageIndex < $1.pageIndex }).first {
                Section {
                    StoredReceiptImage(
                        data: page.imageData,
                        cacheKey: "editor-\(page.id.uuidString)-\(receipt.currentEvidenceDigest)",
                        maxPixelSize: 900
                    )
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                }
            }
            Section("Expense details") {
                TextField("Merchant", text: $merchant)
                DatePicker("Date", selection: $transactionDate, displayedComponents: .date)
                Picker("Matter", selection: $selectedMatter) {
                    Text("Unfiled").tag(nil as ExpenseMatter?)
                    ForEach(matters) { Text($0.name).tag(Optional($0)) }
                }
                Picker("Category", selection: $categoryName) {
                    ForEach(ExpenseCategoryOption.options(customCategories: customCategories, including: categoryName)) { option in
                        Label(option.displayName, systemImage: option.symbol).tag(option.name)
                    }
                }
                TextField("Currency", text: $currencyCode).textInputAutocapitalization(.characters)
                DecimalField("Subtotal", value: $subtotal)
                TextField("Tax label", text: $taxLabel)
                DecimalField("Tax", value: $tax)
                DecimalField("Tip", value: $tip)
                DecimalField("Discount", value: $discount)
                DecimalField("Total", value: $total)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            Section("Line items") {
                if lineItems.isEmpty {
                    Text("No line items saved.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach($lineItems) { $item in
                    LineItemEditorRow(item: $item, currencyCode: currencyCode)
                }
                .onDelete { lineItems.remove(atOffsets: $0) }
                Button("Add line item", systemImage: "plus") {
                    lineItems.append(ReceiptLineItem(description: "", total: 0, confidence: 1))
                }
            }
            Section("Filing") {
                Picker("Payment", selection: $paymentMethod) { ForEach(PaymentMethod.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Reimbursement", selection: $reimbursementStatus) { ForEach(ReimbursementStatus.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Client or cost centre", text: $clientOrCostCentre)
                TextField("Tags, separated by commas", text: $tags)
            }
            Section("Reporting currency") {
                Toggle("Add explicit conversion", isOn: $includesConversion)
                if includesConversion {
                    TextField("Reporting currency (e.g. SGD)", text: $reportingCurrencyCode).textInputAutocapitalization(.characters)
                    DecimalField("Rate: 1 \(currencyCode.uppercased()) equals", value: $exchangeRate)
                    DatePicker("Rate date", selection: $exchangeRateDate, displayedComponents: .date)
                    TextField("Rate source", text: $exchangeRateSource)
                    if exchangeRate > 0, reportingCurrencyCode.count == 3 {
                        LabeledContent("Converted total", value: (total * exchangeRate).formatted(.currency(code: reportingCurrencyCode.uppercased())))
                    }
                }
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
        .alert("Couldn’t save receipt", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func save() {
        record("Merchant", receipt.merchant, merchant)
        record("Date", receipt.transactionDate.formatted(date: .numeric, time: .omitted), transactionDate.formatted(date: .numeric, time: .omitted))
        record("Matter", receipt.matter?.name ?? "Unfiled", selectedMatter?.name ?? "Unfiled")
        record("Category", receipt.categoryDisplayName, categoryName)
        record("Currency", receipt.currencyCode, currencyCode.uppercased())
        record("Subtotal", NSDecimalNumber(decimal: receipt.subtotal).stringValue, NSDecimalNumber(decimal: subtotal).stringValue)
        record("Tax", NSDecimalNumber(decimal: receipt.tax).stringValue, NSDecimalNumber(decimal: tax).stringValue)
        record("Tax label", receipt.taxLabel, taxLabel)
        record("Tip", NSDecimalNumber(decimal: receipt.tip).stringValue, NSDecimalNumber(decimal: tip).stringValue)
        record("Discount", NSDecimalNumber(decimal: receipt.discount).stringValue, NSDecimalNumber(decimal: discount).stringValue)
        record("Total", NSDecimalNumber(decimal: receipt.total).stringValue, NSDecimalNumber(decimal: total).stringValue)
        record("Notes", receipt.notes, notes)
        record("Payment", receipt.paymentMethod.rawValue, paymentMethod.rawValue)
        record("Reimbursement", receipt.reimbursementStatus.rawValue, reimbursementStatus.rawValue)
        record("Client / cost centre", receipt.clientOrCostCentre, clientOrCostCentre)
        record("Tags", receipt.tagsRaw, tags)
        record("Reporting currency", receipt.reportingCurrencyCode, includesConversion ? reportingCurrencyCode.uppercased() : "")
        record("Exchange rate", NSDecimalNumber(decimal: receipt.exchangeRate).stringValue, includesConversion ? NSDecimalNumber(decimal: exchangeRate).stringValue : "0")
        record("Exchange-rate source", receipt.exchangeRateSource, includesConversion ? exchangeRateSource : "")
        record("Line items", "\(receipt.lineItems.count)", "\(lineItems.count)")

        receipt.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.transactionDate = transactionDate
        receipt.matter = selectedMatter
        receipt.categoryRaw = categoryName
        receipt.currencyCode = currencyCode.uppercased()
        receipt.subtotal = subtotal
        receipt.tax = tax
        receipt.tip = tip
        receipt.discount = discount
        receipt.taxLabel = taxLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tax" : taxLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.total = total
        receipt.notes = notes
        receipt.paymentMethod = paymentMethod
        receipt.reimbursementStatus = reimbursementStatus
        receipt.clientOrCostCentre = clientOrCostCentre.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.tagsRaw = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        receipt.reportingCurrencyCode = includesConversion ? reportingCurrencyCode.uppercased() : ""
        receipt.exchangeRate = includesConversion ? exchangeRate : 0
        receipt.exchangeRateDate = includesConversion ? exchangeRateDate : nil
        receipt.exchangeRateSource = includesConversion ? exchangeRateSource.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        receipt.lineItems = lineItems.map { item in
            var normalized = item
            normalized.unitPrice = item.quantity > 0 ? item.total / item.quantity : item.total
            return normalized
        }
        receipt.validationNotes = warnings.joined(separator: "; ")
        receipt.fingerprint = ReceiptEvidence.fingerprint(merchant: merchant, date: transactionDate, total: total, currencyCode: currencyCode)
        receipt.reviewStatus = confirmedAgainstImage ? .verified : .needsReview
        receipt.reviewedAt = confirmedAgainstImage ? .now : nil
        receipt.updatedAt = .now
        do {
            try PersistenceService.save(modelContext)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
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
    @State private var originalImages: [UIImage] = []
    @State private var draft = OCRDraft()
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var didCapture = false
    @State private var didExtract = false
    @State private var isShowingCamera = false
    @State private var isImportingFile = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var cropSelection: ReceiptCropSelection?
    @State private var pendingBatch: [ReceiptBatchItem] = []

    var body: some View {
        Group {
            if !didCapture {
                if isShowingCamera && VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { result in
                        switch result {
                        case .success(let scanned):
                            accept(scanned)
                            isShowingCamera = false
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
            } else if !didExtract {
                ReceiptCapturePreview(
                    images: images,
                    queuedReceiptCount: pendingBatch.count,
                    adjustCrop: { index in
                        cropSelection = ReceiptCropSelection(index: index, image: images[index])
                    },
                    readReceipt: readReceipt,
                    addAnotherReceipt: addAnotherReceipt,
                    startOver: startOver
                )
            } else {
                ReceiptReviewView(draft: draft, images: images, originalImages: originalImages, preselectedMatter: preselectedMatter) {
                    if pendingBatch.isEmpty {
                        dismiss()
                    } else {
                        beginNextBatchReceipt()
                    }
                }
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
                accept(imported)
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.pdf, .image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let imported = try ReceiptFileImporter.images(from: url)
                accept(imported)
            } catch { errorMessage = error.localizedDescription }
        }
        .sheet(item: $cropSelection) { selection in
            ReceiptCropEditor(image: selection.image, pageNumber: selection.index + 1) { cropped in
                guard images.indices.contains(selection.index) else { return }
                images[selection.index] = cropped
            }
        }
        .alert("Couldn’t read receipt", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Enter manually") { didCapture = true; didExtract = true; isReading = false }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private func readReceipt() {
        if !pendingBatch.isEmpty {
            pendingBatch.append(ReceiptBatchItem(images: images, originalImages: originalImages))
            beginNextBatchReceipt()
            return
        }
        recognizeCurrentReceipt()
    }

    private func recognizeCurrentReceipt() {
        isReading = true
        Task {
            do {
                draft = try await ReceiptOCRService().recognize(images: images)
                didExtract = true
            }
            catch { errorMessage = error.localizedDescription }
            isReading = false
        }
    }

    private func accept(_ imported: [UIImage]) {
        guard !imported.isEmpty else {
            isShowingCamera = false
            return
        }
        images = imported
        originalImages = imported
        didCapture = !imported.isEmpty
        didExtract = false
    }

    private func startOver() {
        images = []
        originalImages = []
        draft = OCRDraft()
        didCapture = false
        didExtract = false
        isShowingCamera = false
        photoItems = []
        pendingBatch = []
    }

    private func addAnotherReceipt() {
        guard !images.isEmpty else { return }
        pendingBatch.append(ReceiptBatchItem(images: images, originalImages: originalImages))
        images = []
        originalImages = []
        draft = OCRDraft()
        didCapture = false
        didExtract = false
        isShowingCamera = VNDocumentCameraViewController.isSupported
        photoItems = []
    }

    private func beginNextBatchReceipt() {
        guard !pendingBatch.isEmpty else {
            dismiss()
            return
        }
        let next = pendingBatch.removeFirst()
        images = next.images
        originalImages = next.originalImages
        draft = OCRDraft()
        didCapture = true
        didExtract = false
        recognizeCurrentReceipt()
    }
}

private struct ReceiptBatchItem: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let originalImages: [UIImage]
}

private struct ReceiptCropSelection: Identifiable {
    let index: Int
    let image: UIImage
    var id: Int { index }
}

private struct ReceiptCapturePreview: View {
    let images: [UIImage]
    let queuedReceiptCount: Int
    let adjustCrop: (Int) -> Void
    let readReceipt: () -> Void
    let addAnotherReceipt: () -> Void
    let startOver: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check receipt edges").font(.title2.bold())
                    Text("Make sure every amount is visible. Adjust the four corners on any page before ReceiptSure reads it.")
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    VStack(spacing: 10) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 360)
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Button("Adjust crop for page \(index + 1)", systemImage: "crop") {
                            adjustCrop(index)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("receiptPreview.adjustCrop.\(index)")
                    }
                }

                Button("Read receipt", systemImage: "text.viewfinder", action: readReceipt)
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("receiptPreview.readReceipt")

                Button(queuedReceiptCount == 0 ? "Add another receipt to batch" : "Add another · \(queuedReceiptCount) queued", systemImage: "rectangle.stack.badge.plus", action: addAnotherReceipt)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("Keeps this receipt separate and opens the scanner for the next one.")

                Button("Start over", role: .destructive, action: startOver)
                    .frame(maxWidth: .infinity)
            }
            .padding()
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
    @Query(sort: \CustomExpenseCategory.sortOrder) private var customCategories: [CustomExpenseCategory]
    @State private var draft: OCRDraft
    @State private var selectedMatter: ExpenseMatter?
    @State private var categoryName: String
    @State private var notes = ""
    @State private var paymentMethod = PaymentMethod.unspecified
    @State private var reimbursementStatus = ReimbursementStatus.notApplicable
    @State private var tags = ""
    @State private var clientOrCostCentre = ""
    @State private var reportingCurrencyCode = ""
    @State private var exchangeRate = Decimal.zero
    @State private var exchangeRateDate = Date.now
    @State private var exchangeRateSource = ""
    @State private var includesConversion = false
    @State private var appliedRuleID: UUID?
    @State private var confirmedAgainstImage = false
    @State private var showDuplicateAlert = false
    @State private var images: [UIImage]
    private let originalImages: [UIImage]
    @State private var cropSelection: ReceiptCropSelection?
    @State private var isRereading = false
    @State private var rereadError: String?
    @State private var saveError: String?
    let didSave: () -> Void

    private var currentWarnings: [String] {
        var issues = ReceiptEvidence.warnings(merchant: draft.merchant, date: draft.date, subtotal: draft.subtotal, tax: draft.tax, tip: draft.tip, discount: draft.discount, total: draft.total, currencyCode: draft.currencyCode, ocrConfidence: draft.confidence, reportingCurrencyCode: includesConversion ? reportingCurrencyCode : "", exchangeRate: includesConversion ? exchangeRate : 0, exchangeRateDate: includesConversion ? exchangeRateDate : nil, exchangeRateSource: includesConversion ? exchangeRateSource : "")
        if draft.fieldConfidence.minimumKeyField < 0.65 { issues.append("One or more key fields has low confidence") }
        return issues
    }

    private var fingerprint: String {
        ReceiptEvidence.fingerprint(merchant: draft.merchant, date: draft.date, total: draft.total, currencyCode: draft.currencyCode)
    }

    private var matchingRule: MerchantRule? {
        merchantRules.filter { $0.matches(draft.merchant) }.max { $0.merchantPattern.count < $1.merchantPattern.count }
    }

    init(draft: OCRDraft, images: [UIImage], originalImages: [UIImage], preselectedMatter: ExpenseMatter?, didSave: @escaping () -> Void) {
        self._draft = State(initialValue: draft)
        self._selectedMatter = State(initialValue: preselectedMatter)
        self._categoryName = State(initialValue: draft.category.rawValue)
        self._images = State(initialValue: images)
        self.originalImages = originalImages
        self.didSave = didSave
    }

    var body: some View {
        Form {
            if !images.isEmpty {
                Section {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        VStack(spacing: 8) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).frame(maxWidth: .infinity)
                            Button("Adjust crop for page \(index + 1)", systemImage: "crop") {
                                cropSelection = ReceiptCropSelection(index: index, image: image)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("receiptReview.adjustCrop.\(index)")
                        }
                    }
                    if isRereading {
                        HStack { Spacer(); ProgressView("Reading corrected image…"); Spacer() }
                    }
                } footer: {
                    Text("After a crop change, ReceiptSure reads all pages again. Check the refreshed values before saving.")
                }
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
            Section("Field confidence") {
                ConfidenceRow(title: "Merchant", value: draft.fieldConfidence.merchant)
                ConfidenceRow(title: "Date", value: draft.fieldConfidence.date)
                ConfidenceRow(title: "Currency", value: draft.fieldConfidence.currency)
                ConfidenceRow(title: "Subtotal", value: draft.fieldConfidence.subtotal)
                ConfidenceRow(title: draft.taxLabel, value: draft.fieldConfidence.tax)
                ConfidenceRow(title: "Total", value: draft.fieldConfidence.total)
                if !draft.lineItems.isEmpty { ConfidenceRow(title: "Line items", value: draft.fieldConfidence.lineItems) }
            }
            Section("Check the extracted details") {
                TextField("Merchant", text: $draft.merchant)
                DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                Picker("Matter", selection: $selectedMatter) {
                    Text("Unfiled").tag(nil as ExpenseMatter?)
                    ForEach(matters) { Text($0.name).tag(Optional($0)) }
                }
                Picker("Category", selection: $categoryName) {
                    ForEach(ExpenseCategoryOption.options(customCategories: customCategories, including: categoryName)) { option in
                        Label(option.displayName, systemImage: option.symbol).tag(option.name)
                    }
                }
                TextField("Currency", text: $draft.currencyCode).textInputAutocapitalization(.characters)
            }
            Section("Figures") {
                DecimalField("Subtotal", value: $draft.subtotal)
                TextField("Tax label", text: $draft.taxLabel)
                DecimalField("Tax", value: $draft.tax)
                DecimalField("Tip", value: $draft.tip)
                DecimalField("Discount", value: $draft.discount)
                DecimalField("Total", value: $draft.total)
                let difference = NSDecimalNumber(decimal: draft.subtotal + draft.tax + draft.tip - draft.discount - draft.total).doubleValue
                Label(abs(difference) <= 0.02 ? "Figures reconcile" : "Check the figures", systemImage: abs(difference) <= 0.02 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(abs(difference) <= 0.02 ? .green : .orange)
            }
            Section("Line items") {
                if draft.lineItems.isEmpty {
                    Text("No individual items were detected. You can add them manually if they are needed for allocation or reimbursement.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach($draft.lineItems) { $item in
                    LineItemEditorRow(item: $item, currencyCode: draft.currencyCode)
                }
                .onDelete { draft.lineItems.remove(atOffsets: $0) }
                Button("Add line item", systemImage: "plus") {
                    draft.lineItems.append(ReceiptLineItem(description: "", total: 0, confidence: 1))
                }
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
            Section("Reporting currency") {
                Toggle("Add explicit conversion", isOn: $includesConversion)
                if includesConversion {
                    TextField("Reporting currency (e.g. SGD)", text: $reportingCurrencyCode).textInputAutocapitalization(.characters)
                    DecimalField("Rate: 1 \(draft.currencyCode.uppercased()) equals", value: $exchangeRate)
                    DatePicker("Rate date", selection: $exchangeRateDate, displayedComponents: .date)
                    TextField("Rate source", text: $exchangeRateSource)
                    if exchangeRate > 0, reportingCurrencyCode.count == 3 {
                        LabeledContent("Converted total", value: (draft.total * exchangeRate).formatted(.currency(code: reportingCurrencyCode.uppercased())))
                    }
                }
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
                    if existingReceipts.contains(where: { !$0.isTrashed && $0.fingerprint == fingerprint && !$0.fingerprint.isEmpty }) {
                        showDuplicateAlert = true
                    } else { saveReceipt() }
                }
                .disabled(draft.merchant.trimmingCharacters(in: .whitespaces).isEmpty || draft.total < 0 || draft.currencyCode.count != 3)
            }
        }
        .sheet(item: $cropSelection) { selection in
            ReceiptCropEditor(image: selection.image, pageNumber: selection.index + 1) { cropped in
                guard images.indices.contains(selection.index) else { return }
                images[selection.index] = cropped
                rereadReceipt()
            }
        }
        .alert("Possible duplicate", isPresented: $showDuplicateAlert) {
            Button("Save anyway") { saveReceipt() }
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            Text("A receipt with the same merchant, date, currency, and total is already saved.")
        }
        .alert("Couldn’t re-read receipt", isPresented: Binding(
            get: { rereadError != nil },
            set: { if !$0 { rereadError = nil } }
        )) {
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(rereadError ?? "The crop was kept. Enter or correct the details manually.")
        }
        .alert("Couldn’t save receipt", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func saveReceipt() {
        let status: ReceiptReviewStatus = confirmedAgainstImage ? .verified : .needsReview
        let receipt = Receipt(merchant: draft.merchant, transactionDate: draft.date, currencyCode: draft.currencyCode.uppercased(), subtotal: draft.subtotal, tax: draft.tax, tip: draft.tip, discount: draft.discount, taxLabel: draft.taxLabel, total: draft.total, category: draft.category, notes: notes, ocrText: draft.fullText, ocrConfidence: draft.confidence, reviewStatus: status, reviewedAt: confirmedAgainstImage ? .now : nil, validationNotes: currentWarnings.joined(separator: "; "), fingerprint: fingerprint, paymentMethod: paymentMethod, reimbursementStatus: reimbursementStatus, tags: tags.trimmingCharacters(in: .whitespacesAndNewlines), clientOrCostCentre: clientOrCostCentre.trimmingCharacters(in: .whitespacesAndNewlines), reportingCurrencyCode: includesConversion ? reportingCurrencyCode.uppercased() : "", exchangeRate: includesConversion ? exchangeRate : 0, exchangeRateDate: includesConversion ? exchangeRateDate : nil, exchangeRateSource: includesConversion ? exchangeRateSource.trimmingCharacters(in: .whitespacesAndNewlines) : "", matter: selectedMatter)
        receipt.categoryRaw = categoryName
        modelContext.insert(receipt)
        for (index, image) in images.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.88) {
                let originalData = originalImages.indices.contains(index)
                    ? originalImages[index].jpegData(compressionQuality: 0.92)
                    : data
                let page = ReceiptPage(imageData: data, originalImageData: originalData, pageIndex: index)
                modelContext.insert(page)
                receipt.pages.append(page)
            }
        }
        receipt.lineItems = draft.lineItems.map { item in
            var normalized = item
            normalized.unitPrice = item.quantity > 0 ? item.total / item.quantity : item.total
            return normalized
        }
        receipt.fieldConfidence = draft.fieldConfidence
        EvidenceIntegrityService.seal(receipt)
        do {
            try PersistenceService.save(modelContext)
            didSave()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func rereadReceipt() {
        isRereading = true
        confirmedAgainstImage = false
        Task {
            do {
                draft = try await ReceiptOCRService().recognize(images: images)
                categoryName = draft.category.rawValue
            } catch {
                rereadError = error.localizedDescription
            }
            isRereading = false
        }
    }

    private func apply(_ rule: MerchantRule) {
        categoryName = rule.categoryDisplayName
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

private struct LineItemEditorRow: View {
    @Binding var item: ReceiptLineItem
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Item description", text: $item.description)
            HStack {
                TextField("Quantity", value: $item.quantity, format: .number)
                    .keyboardType(.decimalPad)
                Spacer()
                TextField("Amount", value: $item.total, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
            if item.confidence > 0, item.confidence < 1 {
                Text("OCR confidence \(item.confidence.formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption).foregroundStyle(item.confidence >= 0.65 ? Color.secondary : Color.orange)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
