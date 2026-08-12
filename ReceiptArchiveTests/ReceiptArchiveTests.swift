import Foundation
import SwiftData
import XCTest
@testable import ReceiptSure

final class ReceiptArchiveTests: XCTestCase {
    @MainActor
    func testPrivateCloudSnapshotRoundTripsCustomCategoriesAndDeletionMarkers() async throws {
        let source = try makeModelContainer()
        let sourceContext = source.mainContext
        let category = CustomExpenseCategory(name: "Client Entertainment", symbolName: "briefcase.fill")
        let receipt = Receipt(
            merchant: "Example",
            transactionDate: .now,
            currencyCode: "SGD",
            subtotal: 10,
            tax: 0,
            total: 10,
            category: .other
        )
        receipt.categoryRaw = category.name
        sourceContext.insert(category)
        sourceContext.insert(receipt)
        try sourceContext.save()

        let key = Data(repeating: 7, count: 32)
        let firstSnapshot = try await SecureBackupService.createPrivateCloudSnapshot(modelContext: sourceContext, keyData: key)
        let destination = try makeModelContainer()
        let destinationContext = destination.mainContext
        let firstMerge = try await SecureBackupService.mergePrivateCloudSnapshot(firstSnapshot, modelContext: destinationContext, keyData: key)

        XCTAssertEqual(firstMerge.receipts, 1)
        XCTAssertEqual(firstMerge.categories, 1)
        XCTAssertEqual(try destinationContext.fetch(FetchDescriptor<Receipt>()).first?.categoryRaw, "Client Entertainment")

        PersistenceService.delete(receipt, entityID: receipt.id, entityType: .receipt, from: sourceContext)
        try sourceContext.save()
        let deletionSnapshot = try await SecureBackupService.createPrivateCloudSnapshot(modelContext: sourceContext, keyData: key)
        _ = try await SecureBackupService.mergePrivateCloudSnapshot(deletionSnapshot, modelContext: destinationContext, keyData: key)

        XCTAssertTrue(try destinationContext.fetch(FetchDescriptor<Receipt>()).isEmpty)
        XCTAssertEqual(try destinationContext.fetch(FetchDescriptor<CloudDeletionTombstone>()).count, 1)
    }

    func testDeviceLockDoesNotRestartForFaceIDInactiveTransition() throws {
        var state = DeviceLockState()
        state.requireAuthentication()
        let generation = try XCTUnwrap(state.beginAuthentication())

        XCTAssertTrue(state.isAuthenticating)

        // An inactive scene transition is intentionally not forwarded as a lock.
        XCTAssertNil(state.beginAuthentication())
        state.completeAuthentication(succeeded: true, message: nil, generation: generation)

        XCTAssertTrue(state.isUnlocked)
        XCTAssertFalse(state.isAuthenticating)
        XCTAssertNil(state.authenticationMessage)
    }

    func testDeviceLockIgnoresAuthenticationThatFinishesAfterBackgrounding() throws {
        var state = DeviceLockState()
        state.requireAuthentication()
        let staleGeneration = try XCTUnwrap(state.beginAuthentication())

        state.lockAfterEnteringBackground()
        state.completeAuthentication(succeeded: true, message: nil, generation: staleGeneration)

        XCTAssertFalse(state.isUnlocked)
        XCTAssertFalse(state.isAuthenticating)
    }

    func testSpreadsheetColumnReferencesContinueBeyondZ() {
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 1), "A")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 26), "Z")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 27), "AA")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 32), "AF")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 52), "AZ")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 53), "BA")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 702), "ZZ")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 703), "AAA")
        XCTAssertEqual(SpreadsheetColumnReference.name(for: 0), "")
    }

    func testEvidenceDigestIsOrderIndependentAndDetectsChanges() {
        let first = Data("first page".utf8)
        let second = Data("second page".utf8)
        let ordered = EvidenceIntegrityService.digest([(0, first), (1, second)])
        let reversed = EvidenceIntegrityService.digest([(1, second), (0, first)])
        let changed = EvidenceIntegrityService.digest([(0, first), (1, Data("changed page".utf8))])

        XCTAssertEqual(ordered, reversed)
        XCTAssertNotEqual(ordered, changed)
        XCTAssertEqual(ordered.count, 64)
    }

    func testReceiptFingerprintNormalizesMerchantButKeepsFinancialIdentity() {
        let date = Date(timeIntervalSince1970: 1_767_225_600)
        let first = ReceiptEvidence.fingerprint(merchant: "Acme Store!", date: date, total: 12.50, currencyCode: "sgd")
        let equivalent = ReceiptEvidence.fingerprint(merchant: "ACME STORE", date: date, total: 12.50, currencyCode: "SGD")
        let differentTotal = ReceiptEvidence.fingerprint(merchant: "ACME STORE", date: date, total: 13.50, currencyCode: "SGD")

        XCTAssertEqual(first, equivalent)
        XCTAssertNotEqual(first, differentTotal)
    }

    func testValidationFlagsNonReconciledFigures() {
        let warnings = ReceiptEvidence.warnings(
            merchant: "Merchant",
            date: .now,
            subtotal: 10,
            tax: 1,
            total: 15,
            currencyCode: "USD",
            ocrConfidence: 0.95
        )

        XCTAssertTrue(warnings.contains("Subtotal, tax, tip and discount do not reconcile to total"))
    }

    func testInternationalAmountParsingHandlesDecimalAndThousandsSeparators() {
        XCTAssertEqual(ReceiptTextParsing.amounts(in: "Total EUR 1.234,56"), [Decimal(string: "1234.56")!])
        XCTAssertEqual(ReceiptTextParsing.amounts(in: "Total USD 1,234.56"), [Decimal(string: "1234.56")!])
        XCTAssertEqual(ReceiptTextParsing.amounts(in: "Total CHF 12'345.67"), [Decimal(string: "12345.67")!])
        XCTAssertEqual(ReceiptTextParsing.amounts(in: "Total 12 345,67 €"), [Decimal(string: "12345.67")!])
    }

    func testCurrencyDetectionSupportsCodesAndRegionalSymbols() {
        XCTAssertEqual(ReceiptTextParsing.currency(in: ["TOTAL HK$ 42.00"], defaultCode: "USD").code, "HKD")
        XCTAssertEqual(ReceiptTextParsing.currency(in: ["TOTAL ₹ 850.00"], defaultCode: "USD").code, "INR")
        XCTAssertEqual(ReceiptTextParsing.currency(in: ["TOTAL CHF 19.90"], defaultCode: "EUR").code, "CHF")
        XCTAssertEqual(ReceiptTextParsing.currency(in: ["TOTAL $ 19.90"], defaultCode: "SGD").code, "SGD")
    }

    func testProofPackManifestHashesEveryFileDeterministically() throws {
        let generatedAt = Date(timeIntervalSince1970: 1_767_225_600)
        let files = ["expenses.csv": Data("amount\n12.50".utf8), "summary.pdf": Data("pdf".utf8)]
        let data = try ProofPackManifestBuilder.manifestData(for: files, title: "Trip", generatedAt: generatedAt)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ProofPackManifest.self, from: data)

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.title, "Trip")
        XCTAssertEqual(manifest.files.map(\.path), ["expenses.csv", "summary.pdf"])
        XCTAssertEqual(manifest.files[0].sha256, ProofPackManifestBuilder.sha256Hex(files["expenses.csv"]!))
        XCTAssertEqual(manifest.files[0].sha256.count, 64)
    }

    func testReceiptTrashCanBeRestoredWithoutLosingEvidence() {
        let receipt = Receipt(
            merchant: "Merchant",
            transactionDate: .now,
            currencyCode: "USD",
            subtotal: 10,
            tax: 1,
            total: 11,
            category: .other,
            originalEvidenceDigest: "original",
            currentEvidenceDigest: "current"
        )

        receipt.moveToTrash(at: Date(timeIntervalSince1970: 1_767_225_600))
        XCTAssertTrue(receipt.isTrashed)
        XCTAssertNotNil(receipt.trashedAt)
        XCTAssertEqual(receipt.currentEvidenceDigest, "current")

        receipt.restoreFromTrash()
        XCTAssertFalse(receipt.isTrashed)
        XCTAssertNil(receipt.trashedAt)
        XCTAssertEqual(receipt.originalEvidenceDigest, "original")
    }

    @MainActor
    func testProofPackExportContainsManifestAuditAndBothImageVersions() async throws {
        let receipt = Receipt(
            merchant: "Sample Merchant",
            transactionDate: Date(timeIntervalSince1970: 1_767_225_600),
            currencyCode: "EUR",
            subtotal: 10,
            tax: 2,
            total: 12,
            category: .meals,
            originalEvidenceDigest: "original-seal",
            currentEvidenceDigest: "current-seal"
        )
        let page = ReceiptPage(
            imageData: Data("current-image".utf8),
            originalImageData: Data("original-image".utf8),
            pageIndex: 0,
            receipt: receipt
        )
        receipt.pages.append(page)

        let url = try await ExportService().create(format: .proof, receipts: [receipt], title: "European Trip")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let archive = try Data(contentsOf: url)

        XCTAssertEqual(url.pathExtension.lowercased(), "zip")
        XCTAssertEqual(Array(archive.prefix(2)), Array("PK".utf8))
        XCTAssertNotNil(archive.range(of: Data("manifest.json".utf8)))
        XCTAssertNotNil(archive.range(of: Data("audit/receipt-records.json".utf8)))
        XCTAssertNotNil(archive.range(of: Data("current-page-01.jpg".utf8)))
        XCTAssertNotNil(archive.range(of: Data("original-page-01.jpg".utf8)))
    }

    @MainActor
    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            ExpenseMatter.self,
            Receipt.self,
            ReceiptPage.self,
            ReceiptRevision.self,
            MerchantRule.self,
            CustomExpenseCategory.self,
            CloudDeletionTombstone.self
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
}
