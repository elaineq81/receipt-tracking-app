import SwiftData
import SwiftUI

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case pdf = "PDF report"
    case xlsx = "Excel workbook"
    case csv = "CSV table"
    case docx = "Word report"
    case images = "JPG bundle"
    case proof = "ReceiptSure Proof Pack"

    var id: String { rawValue }
    var isAdvanced: Bool { self == .xlsx || self == .docx || self == .images || self == .proof }
    var symbol: String {
        switch self {
        case .pdf: "doc.richtext"
        case .xlsx: "tablecells"
        case .csv: "text.line.first.and.arrowtriangle.forward"
        case .docx: "doc.text"
        case .images: "photo.stack"
        case .proof: "checkmark.shield"
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
        let active = receipts.filter { !$0.isTrashed }
        guard let selectedMatter else { return active }
        return active.filter { $0.matter?.id == selectedMatter.id }
    }

    var body: some View {
        let report = ReportSummary(receipts: selectedReceipts)
        Form {
            Section("Report scope") {
                Picker("Matter", selection: $selectedMatter) {
                    Text("All receipts").tag(nil as ExpenseMatter?)
                    ForEach(matters) { Text($0.name).tag(Optional($0)) }
                }
                LabeledContent("Receipts", value: "\(report.receipts.count)")
            }
            Section("Report readiness") {
                LabeledContent("Verified", value: "\(report.verifiedCount)")
                LabeledContent("Needs review", value: "\(report.receipts.count - report.verifiedCount)")
                LabeledContent("Figure exceptions", value: "\(report.reconciliationExceptions)")
                LabeledContent("Incomplete conversions", value: "\(report.incompleteConversions)")
                if report.verifiedCount < report.receipts.count {
                    Label("Unverified receipts will be clearly identified in exported records.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Totals by currency") {
                if report.totals.isEmpty { Text("No expenses in this selection").foregroundStyle(.secondary) }
                ForEach(report.totals, id: \.0) { code, total in
                    LabeledContent(code, value: total.formatted(.currency(code: code)))
                }
            }
            if !report.reportingTotals.isEmpty {
                Section("Converted reporting totals") {
                    ForEach(report.reportingTotals, id: \.0) { code, total in
                        LabeledContent(code, value: total.formatted(.currency(code: code)))
                    }
                    Text("Only receipts with a complete rate, effective date, and source are included.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Totals by category") {
                ForEach(report.categories) { section in
                    NavigationLink {
                        CategoryBreakdownView(categoryName: section.categoryName, receipts: section.receipts)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(ExpenseCategory.localizedName(for: section.categoryName), systemImage: section.symbol)
                            Text(section.totalLine).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Totals by date") {
                ForEach(report.dates) { section in
                    LabeledContent(section.day.formatted(date: .abbreviated, time: .omitted), value: section.totalLine)
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
                .disabled(report.receipts.isEmpty || isExporting)
                if !purchases.isPro {
                    Text("CSV is always free. Your first PDF report is included; unlimited PDF, Excel, Word, JPG, and verifiable Proof Pack exports are available with Pro.")
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

    fileprivate static func totalLine(_ rows: [Receipt]) -> String {
        Dictionary(grouping: rows, by: \Receipt.currencyCode)
            .map { currency, values in
                values.reduce(Decimal.zero) { $0 + $1.total }.formatted(.currency(code: currency))
            }
            .sorted().joined(separator: " • ")
    }
}

private struct ReportSummary {
    struct CategorySection: Identifiable {
        let categoryName: String
        let symbol: String
        let receipts: [Receipt]
        let totalLine: String
        var id: String { categoryName }
    }

    struct DateSection: Identifiable {
        let day: Date
        let totalLine: String
        var id: Date { day }
    }

    let receipts: [Receipt]
    let verifiedCount: Int
    let reconciliationExceptions: Int
    let incompleteConversions: Int
    let totals: [(String, Decimal)]
    let reportingTotals: [(String, Decimal)]
    let categories: [CategorySection]
    let dates: [DateSection]

    init(receipts: [Receipt]) {
        self.receipts = receipts
        var verifiedCount = 0
        var reconciliationExceptions = 0
        var incompleteConversions = 0
        var totals: [String: Decimal] = [:]
        var reportingTotals: [String: Decimal] = [:]
        var categories: [String: [Receipt]] = [:]
        var dates: [Date: [Receipt]] = [:]

        for receipt in receipts {
            if receipt.reviewStatus == .verified { verifiedCount += 1 }
            if abs(NSDecimalNumber(decimal: receipt.reconciliationDifference).doubleValue) > 0.02 { reconciliationExceptions += 1 }
            let hasAnyConversion = !receipt.reportingCurrencyCode.isEmpty || receipt.exchangeRate > 0 || receipt.exchangeRateDate != nil || !receipt.exchangeRateSource.isEmpty
            if hasAnyConversion && !receipt.hasCompleteConversion { incompleteConversions += 1 }
            totals[receipt.currencyCode, default: .zero] += receipt.total
            if let reportingTotal = receipt.reportingTotal {
                reportingTotals[receipt.reportingCurrencyCode, default: .zero] += reportingTotal
            }
            categories[receipt.categoryDisplayName, default: []].append(receipt)
            let day = Calendar.current.startOfDay(for: receipt.transactionDate)
            dates[day, default: []].append(receipt)
        }

        self.verifiedCount = verifiedCount
        self.reconciliationExceptions = reconciliationExceptions
        self.incompleteConversions = incompleteConversions
        self.totals = totals.sorted { $0.key < $1.key }
        self.reportingTotals = reportingTotals.sorted { $0.key < $1.key }
        self.categories = categories.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.compactMap { categoryName in
            guard let rows = categories[categoryName], !rows.isEmpty else { return nil }
            return CategorySection(
                categoryName: categoryName,
                symbol: ExpenseCategory.symbol(for: categoryName),
                receipts: rows,
                totalLine: ReportsView.totalLine(rows)
            )
        }
        self.dates = dates.sorted { $0.key > $1.key }.map {
            DateSection(day: $0.key, totalLine: ReportsView.totalLine($0.value))
        }
    }
}

private struct CategoryBreakdownView: View {
    let categoryName: String
    let receipts: [Receipt]
    var body: some View {
        List(receipts) { receipt in ReceiptRow(receipt: receipt) }
            .navigationTitle(ExpenseCategory.localizedName(for: categoryName))
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
