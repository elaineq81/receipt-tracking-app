import Observation
import StoreKit

enum ReceiptSureProducts {
    static let proLifetime = "com.bodywiseremedy.receiptsure.pro.lifetime"
}

enum FreePlanLimits {
    static let matters = 2
    static let receipts = 15
    static let pdfReports = 1
}

enum PaywallReason: String, Identifiable {
    case receiptLimit
    case matterLimit
    case pdfLimit
    case advancedExport
    case automation
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .receiptLimit: "Keep every receipt organized"
        case .matterLimit: "Organize more matters"
        case .pdfLimit: "Create unlimited PDF reports"
        case .advancedExport: "Unlock professional exports"
        case .automation: "File recurring merchants faster"
        case .settings: "Own ReceiptSure Pro for life"
        }
    }

    var detail: String {
        switch self {
        case .receiptLimit:
            "The free plan stores up to \(FreePlanLimits.receipts) receipts. Upgrade once for unlimited receipt storage."
        case .matterLimit:
            "The free plan includes \(FreePlanLimits.matters) matters. Upgrade once to organize unlimited trips, events, and projects."
        case .pdfLimit:
            "Your first complete PDF report is included. ReceiptSure Pro adds unlimited PDF reports."
        case .advancedExport:
            "Excel, Word, and JPG bundles are included with ReceiptSure Pro. CSV remains available for free."
        case .automation:
            "ReceiptSure Pro learns your trusted filing choices with reusable merchant rules."
        case .settings:
            "Unlock unlimited organizing, professional reports, and filing automation with one purchase—no subscription."
        }
    }
}

@MainActor
@Observable
final class PurchaseManager {
    private(set) var product: Product?
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var hasLoadedStore = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    guard case .verified(let transaction) = result else { continue }
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }

        await refreshEntitlements()
        await loadProduct()
    }

    @discardableResult
    func purchase() async -> Bool {
        errorMessage = nil
        guard let product else {
            await loadProduct()
            guard let product else {
                errorMessage = "The App Store could not load ReceiptSure Pro. Please try again shortly."
                return false
            }
            return await purchase(product)
        }
        return await purchase(product)
    }

    @discardableResult
    func restore() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                errorMessage = "No previous ReceiptSure Pro purchase was found for this Apple Account."
            }
            return isPro
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .success(.unverified):
                errorMessage = "The purchase could not be verified. No charge has been applied by ReceiptSure."
            case .pending:
                errorMessage = "The purchase is awaiting approval. Pro will unlock automatically when Apple completes it."
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "The purchase could not be completed. Please try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [ReceiptSureProducts.proLifetime]).first
            hasLoadedStore = true
        } catch {
            hasLoadedStore = true
            errorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var hasProEntitlement = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == ReceiptSureProducts.proLifetime,
               transaction.revocationDate == nil {
                hasProEntitlement = true
            }
        }
        isPro = hasProEntitlement
    }
}
