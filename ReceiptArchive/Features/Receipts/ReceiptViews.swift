import PhotosUI
import SwiftData
import SwiftUI
import UIKit
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
        .navigationTitle("Receipts")
        .searchable(text: $search, prompt: "Merchant, category, or matter")
        .toolbar { Button("Scan", systemImage: "camera.viewfinder", action: scan) }
    }
}

private enum ReceiptScope: String, CaseIterable, Identifiable {
    case all, needsReview, verified
    var id: String { rawValue }
    var title: String { self == .all ? "All" : (self == .needsReview ? "Review" : "Verified") }
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
            Section("Evidence status") {
                Label(receipt.reviewStatus.title, systemImage: receipt.reviewStatus.symbol)
                    .foregroundStyle(receipt.reviewStatus == .verified ? .green : .orange)
                LabeledContent("OCR confidence", value: receipt.ocrConfidence.formatted(.percent.precision(.fractionLength(0))))
                if let reviewedAt = receipt.reviewedAt {
                    LabeledContent("Checked", value: reviewedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if !receipt.validationNotes.isEmpty { Text(receipt.validationNotes).font(.footnote).foregroundStyle(.secondary) }
            }
            if !receipt.notes.isEmpty { Section("Notes") { Text(receipt.notes) } }
            if !receipt.ocrText.isEmpty { Section("Recognized text") { Text(receipt.ocrText).font(.caption).textSelection(.enabled) } }
        }
        .navigationTitle(receipt.merchant.isEmpty ? "Receipt" : receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
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
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        Group {
            if !didCapture {
                if VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { result in
                        switch result {
                        case .success(let scanned):
                            images = scanned
                            didCapture = !scanned.isEmpty
                            if !scanned.isEmpty { readReceipt() } else { dismiss() }
                        case .failure(let error): errorMessage = error.localizedDescription
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    ContentUnavailableView {
                        Label("Scanner unavailable", systemImage: "camera.fill")
                    } description: {
                        Text("Use an iPhone or iPad with a camera, or import receipt photos.")
                    } actions: {
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                            Label("Import receipt photos", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    }
                }
            } else if isReading {
                ProgressView("Reading receipt…").controlSize(.large)
            } else {
                ReceiptReviewView(draft: draft, images: images, preselectedMatter: preselectedMatter) { dismiss() }
            }
        }
        .navigationTitle("Scan receipt")
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

struct ReceiptReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    @Query private var existingReceipts: [Receipt]
    @State private var draft: OCRDraft
    @State private var selectedMatter: ExpenseMatter?
    @State private var notes = ""
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
        let receipt = Receipt(merchant: draft.merchant, transactionDate: draft.date, currencyCode: draft.currencyCode.uppercased(), subtotal: draft.subtotal, tax: draft.tax, total: draft.total, category: draft.category, notes: notes, ocrText: draft.fullText, ocrConfidence: draft.confidence, reviewStatus: status, reviewedAt: confirmedAgainstImage ? .now : nil, validationNotes: currentWarnings.joined(separator: "; "), fingerprint: fingerprint, matter: selectedMatter)
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
}

private struct DecimalField: View {
    let title: String
    @Binding var value: Decimal
    init(_ title: String, value: Binding<Decimal>) { self.title = title; self._value = value }
    var body: some View { TextField(title, value: $value, format: .number.precision(.fractionLength(2))).keyboardType(.decimalPad) }
}
