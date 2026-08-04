import SwiftData
import SwiftUI

struct MattersView: View {
    @Query(sort: \ExpenseMatter.createdAt, order: .reverse) private var matters: [ExpenseMatter]
    let addMatter: () -> Void
    let scan: (ExpenseMatter?) -> Void

    var body: some View {
        Group {
            if matters.isEmpty {
                ContentUnavailableView {
                    Label("No matters yet", systemImage: "folder.badge.plus")
                } description: {
                    Text("Create a trip, event, or matter, then add its first receipt.")
                } actions: {
                    Button("Create a matter", action: addMatter).buttonStyle(.borderedProminent).tint(.teal)
                }
            } else {
                List {
                    Section("Overview") {
                        HStack {
                            SummaryMetric(title: "Matters", value: "\(matters.count)", symbol: "folder")
                            Divider()
                            SummaryMetric(title: "Receipts", value: "\(matters.reduce(0) { $0 + $1.receipts.count })", symbol: "doc.text")
                        }
                        .frame(height: 72)
                    }
                    Section("Trips, events & matters") {
                        ForEach(matters) { matter in
                            NavigationLink {
                                MatterDetailView(matter: matter, scan: { scan(matter) })
                            } label: {
                                MatterRow(matter: matter)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("ReceiptSure")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Scan receipt", systemImage: "camera.viewfinder") { scan(nil) }
                Button("New matter", systemImage: "plus", action: addMatter)
            }
        }
    }
}

private struct MatterRow: View {
    let matter: ExpenseMatter

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill").font(.title2).foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 4) {
                Text(matter.name).font(.headline)
                Text("\(matter.receipts.count) receipt\(matter.receipts.count == 1 ? "" : "s") • \(matter.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let first = matter.totalByCurrency.sorted(by: { $0.key < $1.key }).first {
                    Text(first.value.formatted(.currency(code: first.key))).font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 5)
    }
}

struct MatterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let matter: ExpenseMatter
    let scan: () -> Void

    var sortedReceipts: [Receipt] { matter.receipts.sorted { $0.transactionDate > $1.transactionDate } }

    var body: some View {
        List {
            if !matter.details.isEmpty { Section { Text(matter.details) } }
            Section("Totals") {
                ForEach(matter.totalByCurrency.sorted(by: { $0.key < $1.key }), id: \.key) { code, total in
                    LabeledContent(code, value: total.formatted(.currency(code: code)))
                }
            }
            Section("Receipts") {
                if sortedReceipts.isEmpty {
                    ContentUnavailableView("No receipts", systemImage: "doc.text", description: Text("Scan the first receipt for this matter."))
                }
                ForEach(sortedReceipts) { receipt in
                    NavigationLink { ReceiptDetailView(receipt: receipt) } label: { ReceiptRow(receipt: receipt) }
                }
                .onDelete { offsets in offsets.map { sortedReceipts[$0] }.forEach(modelContext.delete) }
            }
        }
        .navigationTitle(matter.name)
        .toolbar { Button("Scan", systemImage: "camera.viewfinder", action: scan) }
    }
}

struct MatterEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var details = ""
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now

    var body: some View {
        Form {
            Section("Matter") {
                TextField("Trip, event, or matter name", text: $name)
                TextField("Notes (optional)", text: $details, axis: .vertical)
            }
            Section("Dates") {
                DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                Toggle("Add end date", isOn: $hasEndDate)
                if hasEndDate { DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date) }
            }
        }
        .navigationTitle("New matter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    modelContext.insert(ExpenseMatter(name: name.trimmingCharacters(in: .whitespacesAndNewlines), details: details, startDate: startDate, endDate: hasEndDate ? endDate : nil))
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
