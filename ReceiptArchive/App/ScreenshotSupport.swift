import Foundation
import SwiftData

enum ScreenshotSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-ReceiptSureScreenshotMode")
    }

    static var requestedTab: AppTab {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-ReceiptSureScreenshotTab"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1) else {
            return .matters
        }
        switch ProcessInfo.processInfo.arguments[index + 1].lowercased() {
        case "receipts": return .receipts
        case "reports": return .reports
        case "settings": return .settings
        default: return .matters
        }
    }

    @MainActor
    static func prepare(modelContext: ModelContext) {
        guard isEnabled else { return }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "deviceLockEnabled")
        UserDefaults.standard.set(false, forKey: "privacyScreenEnabled")

        let existing = (try? modelContext.fetchCount(FetchDescriptor<ExpenseMatter>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar(identifier: .gregorian)
        let singaporeTrip = ExpenseMatter(
            name: "Singapore Client Trip",
            details: "Travel, meals and client expenses · Cost centre SG-2408",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 24))!
        )
        let launchEvent = ExpenseMatter(
            name: "Product Launch Event",
            details: "Venue, supplies and team hospitality",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        )
        modelContext.insert(singaporeTrip)
        modelContext.insert(launchEvent)

        let rows: [(String, Int, Decimal, Decimal, ExpenseCategory, ExpenseMatter, PaymentMethod)] = [
            ("Marina Bay Hotel", 21, 780, 70.20, .accommodation, singaporeTrip, .companyCard),
            ("Grab", 22, 32.40, 2.59, .transport, singaporeTrip, .companyCard),
            ("Common Man Coffee Roasters", 22, 86, 7.74, .meals, singaporeTrip, .personalCard),
            ("Changi Airport Group", 24, 48, 4.32, .transport, singaporeTrip, .companyCard),
            ("Suntec Convention Centre", 15, 1250, 112.50, .fees, launchEvent, .companyCard),
            ("Popular Bookstore", 16, 138, 12.42, .supplies, launchEvent, .personalCard),
        ]

        for (index, row) in rows.enumerated() {
            let total = row.2 + row.3
            let receipt = Receipt(
                merchant: row.0,
                transactionDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: row.1, hour: 12))!,
                currencyCode: "SGD",
                subtotal: row.2,
                tax: row.3,
                total: total,
                category: row.4,
                notes: index == 2 ? "Client lunch · Project Atlas" : "",
                ocrText: "ReceiptSure on-device OCR sample",
                ocrConfidence: index == 5 ? 0.82 : 0.96,
                reviewStatus: index == 5 ? .needsReview : .verified,
                reviewedAt: index == 5 ? nil : .now,
                validationNotes: index == 5 ? "Confirm merchant tax registration number" : "",
                fingerprint: "screenshot-\(index)",
                paymentMethod: row.6,
                reimbursementStatus: row.6 == .personalCard ? .toSubmit : .notApplicable,
                tags: index == 2 ? "client, meals" : "business",
                clientOrCostCentre: row.5 === singaporeTrip ? "SG-2408" : "EVENT-0715",
                matter: row.5
            )
            modelContext.insert(receipt)
            row.5.receipts.append(receipt)
        }
        try? modelContext.save()
    }
}
