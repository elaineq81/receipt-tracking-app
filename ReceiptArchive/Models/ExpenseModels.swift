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
    var paymentMethodRaw: String = PaymentMethod.unspecified.rawValue
    var reimbursementStatusRaw: String = ReimbursementStatus.notApplicable.rawValue
    var tagsRaw: String = ""
    var clientOrCostCentre: String = ""
    var matter: ExpenseMatter?

    @Relationship(deleteRule: .cascade, inverse: \ReceiptPage.receipt)
    var pages: [ReceiptPage]

    @Relationship(deleteRule: .cascade, inverse: \ReceiptRevision.receipt)
    var revisions: [ReceiptRevision]

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
        paymentMethod: PaymentMethod = .unspecified,
        reimbursementStatus: ReimbursementStatus = .notApplicable,
        tags: String = "",
        clientOrCostCentre: String = "",
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
        self.paymentMethodRaw = paymentMethod.rawValue
        self.reimbursementStatusRaw = reimbursementStatus.rawValue
        self.tagsRaw = tags
        self.clientOrCostCentre = clientOrCostCentre
        self.matter = matter
        self.pages = []
        self.revisions = []
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var reviewStatus: ReceiptReviewStatus {
        get { ReceiptReviewStatus(rawValue: reviewStatusRaw) ?? .needsReview }
        set { reviewStatusRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .unspecified }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var reimbursementStatus: ReimbursementStatus {
        get { ReimbursementStatus(rawValue: reimbursementStatusRaw) ?? .notApplicable }
        set { reimbursementStatusRaw = newValue.rawValue }
    }

    var attentionScore: Int {
        var score = reviewStatus == .needsReview ? 40 : 0
        score += Int(max(0, min(30, (0.85 - ocrConfidence) * 100)))
        score += min(24, validationMessages.count * 8)
        if matter == nil { score += 6 }
        return score
    }

    var validationMessages: [String] {
        validationNotes.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case unspecified = "Not specified"
    case personalCard = "Personal card"
    case companyCard = "Company card"
    case cash = "Cash"
    case bankTransfer = "Bank transfer"
    case digitalWallet = "Digital wallet"

    var id: String { rawValue }
}

enum ReimbursementStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case notApplicable = "Not applicable"
    case toSubmit = "To submit"
    case submitted = "Submitted"
    case reimbursed = "Reimbursed"

    var id: String { rawValue }
}

@Model
final class MerchantRule {
    @Attribute(.unique) var id: UUID
    var merchantPattern: String
    var categoryRaw: String
    var paymentMethodRaw: String
    var tags: String
    var clientOrCostCentre: String
    var matterID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        merchantPattern: String,
        category: ExpenseCategory = .other,
        paymentMethod: PaymentMethod = .unspecified,
        tags: String = "",
        clientOrCostCentre: String = "",
        matterID: UUID? = nil
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryRaw = category.rawValue
        self.paymentMethodRaw = paymentMethod.rawValue
        self.tags = tags
        self.clientOrCostCentre = clientOrCostCentre
        self.matterID = matterID
        self.createdAt = .now
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .unspecified }
        set { paymentMethodRaw = newValue.rawValue }
    }

    func matches(_ merchant: String) -> Bool {
        let pattern = merchantPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        return !pattern.isEmpty && merchant.localizedCaseInsensitiveContains(pattern)
    }
}

enum ReceiptReviewStatus: String, Codable, Sendable {
    case needsReview
    case verified

    var title: String { self == .verified ? "Verified" : "Needs review" }
    var symbol: String { self == .verified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill" }
}

@Model
final class ReceiptRevision {
    @Attribute(.unique) var id: UUID
    var changedAt: Date
    var fieldName: String
    var previousValue: String
    var newValue: String
    var reason: String
    var receipt: Receipt?

    init(
        id: UUID = UUID(),
        changedAt: Date = .now,
        fieldName: String,
        previousValue: String,
        newValue: String,
        reason: String = "",
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.changedAt = changedAt
        self.fieldName = fieldName
        self.previousValue = previousValue
        self.newValue = newValue
        self.reason = reason
        self.receipt = receipt
    }
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
