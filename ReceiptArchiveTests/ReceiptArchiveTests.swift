import Foundation
import XCTest
@testable import ReceiptSure

final class ReceiptArchiveTests: XCTestCase {
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
}
