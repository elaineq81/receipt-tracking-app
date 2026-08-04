import SwiftData
import SwiftUI

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF report"
    case xlsx = "Excel workbook"
    case csv = "CSV table"
    case docx = "Word report"
    case images = "JPG bundle"

    var id: String { rawValue }
    var isAdvanced: Bool { self == .xlsx || self == .docx || self == .images }
    var symbol: String {
        switch self {
        case .pdf: "doc.richtext"
        case .xlsx: "tablecells"
        case .csv: "text.line.first.and.arrowtriangle.forward"
        case .docx: "doc.text"
        case .images: "photo.stack"
        }
    }
}

struct ReportsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Query(sort: \Receipt.transactionDate, order: .reverse) private var receipts: [Receipt]
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    @AppStorage("freePDFReportsCreated") private var freePDFReportsCreated = 0
    let presentPaywall: (PaywallReason) -> Void
    @State private var selectedMatter: ExpenseMatter?
    @State private var format = ExportFormat.pdf
    @State private var shareItem: ShareItem?
    @State private var isExporting = false
    @State private var errorMessage: String?

    private var selectedReceipts: [Receipt] {
        guard let selectedMatter else { return receipts }
        return receipts.filter { $0.matter?.id == selectedMatter.id }
    }

    private var totals: [(String, Decimal)] {
        Dictionary(grouping: selectedReceipts, by: \Receipt.currencyCode)
            .map { ($0.key, $0.value.reduce(Decimal.zero) { $0 + $1.total }) }
            .sorted { $0.0 < $1.0 }
    }

    private var reportingTotals: [(String, Decimal)] {
        Dictionary(grouping: selectedReceipts.filter(\.hasCompleteConversion), by: \Receipt.reportingCurrencyCode)
            .map { currency, values in (currency, values.compactMap(\.reportingTotal).reduce(Decimal.zero, +)) }
            .sorted { $0.0 < $1.0 }
    }

    private var reconciliationExceptions: Int {
        selectedReceipts.filter { abs(NSDecimalNumber(decimal: $0.reconciliationDifference).doubleValue) > 0.02 }.count
    }

    private var incompleteConversions: Int {
        selectedReceipts.filter {
            let hasAny = !$0.reportingCurrencyCode.isEmpty || $0.exchangeRate > 0 || $0.exchangeRateDate != nil || !$0.exchangeRateSource.isEmpty
            return hasAny && !$0.hasCompleteConversion
        }.count
    }

    var body: some View {
        Form {
            Section("Report scope") {
                Picker("Matter", selection: $selectedMatter) {
                    Text("All receipts").tag(nil as ExpenseMatter?)
                    ForEach(matters) { Text($0.name).tag(Optional($0)) }
                }
                LabeledContent("Receipts", value: "\(selectedReceipts.count)")
            }
            Section("Report readiness") {
                let verified = selectedReceipts.filter { $0.reviewStatus == .verified }.count
                LabeledContent("Verified", value: "\(verified)")
                LabeledContent("Needs review", value: "\(selectedReceipts.count - verified)")
                LabeledContent("Figure exceptions", value: "\(reconciliationExceptions)")
                LabeledContent("Incomplete conversions", value: "\(incompleteConversions)")
                if verified < selectedReceipts.count {
                    Label("Unverified receipts will be clearly identified in exported records.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Totals by currency") {
                if totals.isEmpty { Text("No expenses in this selection").foregroundStyle(.secondary) }
                ForEach(totals, id: \.0) { code, total in
                    LabeledContent(code, value: total.formatted(.currency(code: code)))
                }
            }
            if !reportingTotals.isEmpty {
                Section("Converted reporting totals") {
                    ForEach(reportingTotals, id: \.0) { code, total in
                        LabeledContent(code, value: total.formatted(.currency(code: code)))
                    }
                    Text("Only receipts with a complete rate, effective date, and source are included.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Totals by category") {
                ForEach(ExpenseCategory.allCases) { category in
                    let rows = selectedReceipts.filter { $0.category == category }
                    if !rows.isEmpty {
                        NavigationLink {
                            CategoryBreakdownView(category: category, receipts: rows)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(category.rawValue, systemImage: category.symbol)
                                Text(Self.totalLine(rows)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section("Totals by date") {
                ForEach(Dictionary(grouping: selectedReceipts, by: { Calendar.current.startOfDay(for: $0.transactionDate) }).keys.sorted(by: >), id: \.self) { day in
                    let rows = selectedReceipts.filter { Calendar.current.isDate($0.transactionDate, inSameDayAs: day) }
                    LabeledContent(day.formatted(date: .abbreviated, time: .omitted), value: Self.totalLine(rows))
                }
            }
            Section("Export") {
                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases) { option in
                        Label(option.rawValue + proSuffix(for: option), systemImage: option.symbol).tag(option)
                    }
                }
                Button {
                    export()
                } label: {
                    HStack {
                        if isExporting { ProgressView() }
                        Label(isExporting ? "Preparing…" : "Create & share report", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(selectedReceipts.isEmpty || isExporting)
                if !purchases.isPro {
                    Text("CSV is always free. Your first PDF report is included; unlimited PDF, Excel, Word, and JPG exports are available with Pro.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Reports")
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        .alert("Export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private func export() {
        if !purchases.isPro {
            if format.isAdvanced {
                presentPaywall(.advancedExport)
                return
            }
            if format == .pdf && freePDFReportsCreated >= FreePlanLimits.pdfReports {
                presentPaywall(.pdfLimit)
                return
            }
        }

        isExporting = true
        let rows = selectedReceipts
        let title = selectedMatter?.name ?? "All Expenses"
        Task {
            do {
                let url = try await ExportService().create(format: format, receipts: rows, title: title)
                if !purchases.isPro && format == .pdf {
                    freePDFReportsCreated += 1
                }
                shareItem = ShareItem(url: url)
            } catch { errorMessage = error.localizedDescription }
            isExporting = false
        }
    }

    private func proSuffix(for option: ExportFormat) -> String {
        guard !purchases.isPro else { return "" }
        if option.isAdvanced { return " · Pro" }
        if option == .pdf && freePDFReportsCreated >= FreePlanLimits.pdfReports { return " · Pro" }
        return ""
    }

    private static func totalLine(_ rows: [Receipt]) -> String {
        Dictionary(grouping: rows, by: \Receipt.currencyCode)
            .map { currency, values in
                values.reduce(Decimal.zero) { $0 + $1.total }.formatted(.currency(code: currency))
            }
            .sorted().joined(separator: " • ")
    }
}

private struct CategoryBreakdownView: View {
    let category: ExpenseCategory
    let receipts: [Receipt]
    var body: some View {
        List(receipts) { receipt in ReceiptRow(receipt: receipt) }
            .navigationTitle(category.rawValue)
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
