import Foundation
import SwiftData

@Model
final class ExpenseMatter {
    @Attribute(.unique) var id: UUID
    var name: String
    var details: String
    var startDate: Date
    var endDate: Date?
    var createdAt: Date
    var colorName: String

    @Relationship(deleteRule: .cascade, inverse: \Receipt.matter)
    var receipts: [Receipt]

    init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        startDate: Date = .now,
        endDate: Date? = nil,
        colorName: String = "teal"
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = .now
        self.colorName = colorName
        self.receipts = []
    }

    var totalByCurrency: [String: Decimal] {
        Dictionary(grouping: receipts, by: \Receipt.currencyCode)
            .mapValues { rows in rows.reduce(Decimal.zero) { $0 + $1.total } }
    }
}

@Model
final class Receipt {
    @Attribute(.unique) var id: UUID
    var merchant: String
    var transactionDate: Date
    var currencyCode: String
    var subtotal: Decimal
    var tax: Decimal
    var total: Decimal
    var categoryRaw: String
    var notes: String
    var createdAt: Date
    var ocrText: String
    var ocrConfidence: Double = 0
    var reviewStatusRaw: String = ReceiptReviewStatus.needsReview.rawValue
    var reviewedAt: Date?
    var validationNotes: String = ""
    var fingerprint: String = ""
    var matter: ExpenseMatter?

    @Relationship(deleteRule: .cascade, inverse: \ReceiptPage.receipt)
    var pages: [ReceiptPage]

    init(
        id: UUID = UUID(),
        merchant: String,
        transactionDate: Date,
        currencyCode: String,
        subtotal: Decimal,
        tax: Decimal,
        total: Decimal,
        category: ExpenseCategory,
        notes: String = "",
        ocrText: String = "",
        ocrConfidence: Double = 0,
        reviewStatus: ReceiptReviewStatus = .needsReview,
        reviewedAt: Date? = nil,
        validationNotes: String = "",
        fingerprint: String = "",
        matter: ExpenseMatter? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.transactionDate = transactionDate
        self.currencyCode = currencyCode
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.createdAt = .now
        self.ocrText = ocrText
        self.ocrConfidence = ocrConfidence
        self.reviewStatusRaw = reviewStatus.rawValue
        self.reviewedAt = reviewedAt
        self.validationNotes = validationNotes
        self.fingerprint = fingerprint
        self.matter = matter
        self.pages = []
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var reviewStatus: ReceiptReviewStatus {
        get { ReceiptReviewStatus(rawValue: reviewStatusRaw) ?? .needsReview }
        set { reviewStatusRaw = newValue.rawValue }
    }
}

enum ReceiptReviewStatus: String, Codable, Sendable {
    case needsReview
    case verified

    var title: String { self == .verified ? "Verified" : "Needs review" }
    var symbol: String { self == .verified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill" }
}

@Model
final class ReceiptPage {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    var pageIndex: Int
    var receipt: Receipt?

    init(id: UUID = UUID(), imageData: Data, pageIndex: Int, receipt: Receipt? = nil) {
        self.id = id
        self.imageData = imageData
        self.pageIndex = pageIndex
        self.receipt = receipt
    }
}

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case accommodation = "Accommodation"
    case meals = "Meals"
    case transport = "Transport"
    case fuel = "Fuel"
    case supplies = "Supplies"
    case entertainment = "Entertainment"
    case fees = "Fees"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .accommodation: "bed.double.fill"
        case .meals: "fork.knife"
        case .transport: "car.fill"
        case .fuel: "fuelpump.fill"
        case .supplies: "shippingbox.fill"
        case .entertainment: "ticket.fill"
        case .fees: "creditcard.fill"
        case .other: "square.grid.2x2.fill"
        }
    }
}
