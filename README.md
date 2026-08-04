# ReceiptSure for iOS

ReceiptSure is a native, offline-first SwiftUI app for scanning and organizing receipts by trip, event, or matter. It uses VisionKit for automatic document detection/cropping, Vision for on-device OCR, SwiftData for local persistence, and Apple’s share sheet for exports.

Its differentiator is a **Receipt Evidence Record**: visible OCR confidence, validation warnings, duplicate protection, human verification, and evidence status carried into exported reports. See `PRODUCT_STRATEGY.md` for the competitive position and delivery roadmap.

## Included in this build

- Create trips, events, and matters with optional dates and notes.
- Scan multi-page receipts with `VNDocumentCameraViewController` automatic edge detection and crop.
- Extract merchant, date, currency, subtotal, tax, total, and a suggested category on-device.
- Review and correct every extracted field before saving.
- See OCR confidence and validation warnings, verify against the image, and catch likely duplicates before saving.
- Edit saved receipts with a permanent field-by-field before/after history and optional change reason.
- Work through a risk-ranked Attention inbox so the most uncertain records are corrected first.
- Import existing receipt images and multi-page PDFs from Files, or choose images through Apple’s privacy-preserving Photos picker.
- Track payment method, reimbursement status, tags, and client or cost centre through review, editing, and exports.
- Create reusable merchant rules that suggest trusted filing details without silently overwriting the receipt.
- Reconcile subtotal, named tax, tip, and discount against the final total with a visible exception when figures differ.
- Record an optional reporting-currency rate together with its source and effective date; incomplete conversions are excluded from converted totals.
- Produce PDF evidence packs with a readiness cover sheet, original-currency totals, supported reporting totals, exceptions, and a receipt-image appendix.
- Protect the app with Face ID, Touch ID, or device passcode and obscure private content in the app switcher.
- Create password-protected AES-GCM archives containing receipt images, revisions, matters, and rules; restore merges missing records without deleting current data.
- Monitor backup health and see the last successful restore time.
- Organize and search receipts by date, merchant, category, and matter.
- Summaries by matter, category, date, and currency. Different currencies are never silently combined.
- Report-readiness counts and verification status embedded in PDF, XLSX, and CSV outputs.
- Export a selection as PDF (including receipt images), valid XLSX, CSV, DOCX, or a ZIP containing JPGs and a CSV index.
- Local-only storage, a privacy manifest, and a clear camera purpose string.
- An original, opaque 1024×1024 App Store icon.

## Open in Xcode

This repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to produce a deterministic Xcode project.

1. On a Mac, install Xcode 16 or newer and XcodeGen (`brew install xcodegen`).
2. In this folder, run `xcodegen generate`.
3. Open `ReceiptArchive.xcodeproj` and select the `ReceiptArchive` scheme.
4. In Signing & Capabilities, select your Apple Developer team and register or replace `com.bodywiseremedy.receiptsure`.
5. Run on a physical iPhone or iPad to test document scanning. The simulator cannot exercise the document camera.

Minimum deployment target: iOS 17.0. No third-party runtime packages are required.

## Product decisions

- The app is offline-first and has no account, backend, analytics, ads, or tracking.
- The system photo picker is preferred for future image import because it avoids broad photo-library access.
- OCR is assistance, not an accounting guarantee. The save flow requires user review.
- Totals are grouped by ISO currency code; conversion is intentionally not guessed.
- The initial bundle ID is a placeholder and must match the identifier created in the developer account.

See `RELEASE_CHECKLIST.md` for the TestFlight and App Store Connect pathway.

## GitHub trail

The repository is structured as a standalone public iOS project, separate from Bodywise Remedy. `.github/workflows/ios-ci.yml` generates the Xcode project and builds it on a hosted Mac for every push and pull request to `main`. See `GITHUB_ACTIONS_IOS.md` and `IOS_APP_READINESS.md` for the verification and handoff trail.

## Interactive web preview

The browser-based product sample lives in `web-demo/` and is deployed through the dedicated Receipt Tracking Vercel project: <https://receipt-tracking-app-lemon.vercel.app>.

The preview uses sample data and simulates the proposed iPhone workflow. The native SwiftUI app remains the production implementation for camera scanning, on-device OCR, local persistence, and file exports.
