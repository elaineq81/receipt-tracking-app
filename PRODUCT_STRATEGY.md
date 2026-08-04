# ReceiptArchive product strategy

## Product promise

ReceiptArchive is the private, evidence-grade home for expenses connected to a trip, event, claim, project, or other matter. It turns receipt images into records people can verify, find, and hand to an accountant without rebuilding the spreadsheet.

## Competitive landscape

The market separates into two broad groups:

- Enterprise suites such as SAP Concur, Expensify, and Zoho Expense lead on company cards, approval chains, travel booking, and accounting integrations.
- Personal receipt organizers such as Smart Receipts, QuickReceipts, and Shoeboxed lead on capture, categorization, mileage, folders, and common report formats.

ReceiptArchive should not imitate the breadth of an enterprise travel platform. Its opening is a narrower, better-finished workflow for individuals and small teams who need trustworthy evidence organized around a matter.

## Defensible advantage: the Receipt Evidence Record

Every saved receipt should become more than an image and a guessed total. It should contain:

1. The original receipt image and OCR text.
2. Structured merchant, date, currency, subtotal, tax, total, and category fields.
3. Visible OCR confidence and validation warnings.
4. A human verification state and verification timestamp.
5. Duplicate protection based on merchant, date, currency, and total.
6. A future revision history showing what changed, when, and why.
7. An export-ready evidence status that follows the record into PDF, Excel, CSV, and Word reports.

This makes trust a product feature instead of hiding uncertainty behind automation.

## Product principles

- **Local-first:** core scanning, OCR, organization, and export work without an account or network connection.
- **No silent assumptions:** currencies are never combined without an explicit conversion method and date.
- **Correction-first AI:** automation proposes; the receipt image remains available while the person checks the answer.
- **Matter-first organization:** receipts belong to trips, events, claims, projects, clients, or other user-defined matters.
- **Accountant-clean outputs:** exports are designed as final handoff documents, not raw database dumps.
- **Calm, native design:** Apple conventions, restrained color, clear status, excellent accessibility, and no decorative AI theatre.

## Delivery roadmap

### Foundation — implemented or in progress

- VisionKit document capture with automatic edge detection and cropping.
- On-device Vision OCR and field extraction.
- Matter, receipt, page, category, and multi-currency data model.
- Human review, confidence score, validation warnings, verification state, and duplicate warning.
- PDF, XLSX, CSV, DOCX, and JPG bundle exports.
- Report readiness and evidence status in exported data.

### Professional workflow

- Edit existing receipts with a durable field-by-field revision history.
- Smart “Needs attention” inbox ordered by risk, not capture date.
- Multi-page receipt splitting and page quality checks.
- Import receipt PDFs and images from Files, Photos, Share Sheet, and email forwarding.
- Rules for repeat merchants, categories, payment methods, and matter assignment.
- Tags, payment method, reimbursement state, client, cost centre, and custom fields.
- Line-item extraction where it materially improves tax or category reporting.

### Evidence-grade reporting

- Reporting currency with explicit exchange rate, source, and effective date.
- Reconciliation checks for subtotal, tax, tips, discounts, and total.
- Per-matter cover sheet, exceptions page, verification ledger, and receipt appendix.
- Accountant profiles with reusable column mappings and export presets.
- Report locking and a content checksum so a delivered evidence pack can be verified.

### Secure continuity

- Face ID app lock and privacy-screen controls.
- Encrypted iCloud sync and device-to-device continuity as an opt-in feature.
- Backup health indicator, archive import, and disaster-recovery test.
- Optional collaboration with explicit roles and a complete audit trail.

## Success measures

- Median time from capture to verified receipt under 20 seconds.
- At least 90% of high-quality scans require no correction to merchant, date, currency, and total.
- Duplicate save rate below 0.5%.
- At least 95% of receipts in an exported report are verified.
- A new user can create a matter, scan, verify, and export without documentation.

## What we deliberately postpone

Bank feeds, corporate card issuing, travel booking, payroll, and deep enterprise approvals are expensive surfaces already served by established platforms. They should only enter the roadmap after ReceiptArchive has proven that its evidence record and matter-based reporting solve a distinct customer problem.
