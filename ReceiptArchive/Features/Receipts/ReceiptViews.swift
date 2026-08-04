import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

struct ReceiptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.transactionDate, order: .reverse) private var receipts: [Receipt]
    @State private var search = ""
    let scan: () -> Void

    private var filtered: [Receipt] {
        guard !search.isEmpty else { return receipts }
        return receipts.filter { $0.merchant.localizedCaseInsensitiveContains(search) || $0.categoryRaw.localizedCaseInsensitiveContains(search) || ($0.matter?.name.localizedCaseInsensitiveContains(search) ?? false) }
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

struct ReceiptRow: View {
    let receipt: Receipt
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: receipt.category.symbol)
                .frame(width: 38, height: 38).background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 9)).foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.merchant.isEmpty ? "Unlabeled receipt" : receipt.merchant).font(.headline)
                Text([receipt.category.rawValue, receipt.matter?.name].compactMap { $0 }.joined(separator: " • ")).font(.caption).foregroundStyle(.secondary)
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
    @State private var draft: OCRDraft
    @State private var selectedMatter: ExpenseMatter?
    @State private var notes = ""
    let images: [UIImage]
    let didSave: () -> Void

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
            Section { Text("OCR can make mistakes. Confirm the merchant, date, currency, and total against the image before saving.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Review receipt")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let receipt = Receipt(merchant: draft.merchant, transactionDate: draft.date, currencyCode: draft.currencyCode.uppercased(), subtotal: draft.subtotal, tax: draft.tax, total: draft.total, category: draft.category, notes: notes, ocrText: draft.fullText, matter: selectedMatter)
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
                .disabled(draft.merchant.trimmingCharacters(in: .whitespaces).isEmpty || draft.total < 0 || draft.currencyCode.count != 3)
            }
        }
    }
}

private struct DecimalField: View {
    let title: String
    @Binding var value: Decimal
    init(_ title: String, value: Binding<Decimal>) { self.title = title; self._value = value }
    var body: some View { TextField(title, value: $value, format: .number.precision(.fractionLength(2))).keyboardType(.decimalPad) }
}
