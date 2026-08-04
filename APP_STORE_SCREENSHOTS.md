# ReceiptSure App Store screenshot plan

Capture screenshots from the real signed or simulator-built iOS app, not from the browser preview. Use fictional receipts with no real names, addresses, card numbers, tax identifiers, booking references, or expense claims.

## Required capture set

Prepare six portrait screenshots from a current 6.9-inch iPhone simulator or device at its native accepted resolution. Depending on the selected 6.9-inch model, Apple currently accepts 1260 × 2736, 1290 × 2796, or 1320 × 2868 pixels. Use one device and one native dimension for the complete set. Do not resize screenshots manually, include transparency, show developer tools, or mix device sizes in one set.

| Order | Real app state | Suggested caption |
| --- | --- | --- |
| 1 | Matters dashboard with three fictional matters and attention count | Every expense has a place |
| 2 | VisionKit camera framing a clearly fictional receipt | Capture cleanly in seconds |
| 3 | OCR review with confidence and validation visible | Check every important figure |
| 4 | Receipt detail showing verified status and correction history | Keep evidence you can trust |
| 5 | Per-matter report with category and separate-currency totals | Tidy totals without currency guesswork |
| 6 | Export and secure-backup choices | Share reports. Protect the originals. |

Also capture one separate, unframed screenshot of the **ReceiptSure Pro** purchase sheet for the non-consumable product’s App Review attachment. It must show the one-time/no-subscription wording, Restore Purchases, and StoreKit’s localized price. This review attachment is not part of the six public product-page screenshots.

## Screenshot data pack

Use neutral fictional examples consistently:

- Matters: “Tokyo work trip”, “Studio supplies”, “Client workshop”
- Merchants: “Kissa Sample”, “Harbour Stationery”, “Northline Hotel”
- Currencies: SGD and JPY, displayed separately unless a clearly labeled sample exchange rate is supplied
- Dates: recent but not future dates at capture time
- Statuses: a mix of Verified and Needs review so the product advantage is visible

## Final checks

- [ ] Status bar time, battery, and connectivity look intentional.
- [ ] No permission alert, keyboard, debug banner, cursor, or personal notification is visible.
- [ ] Text is legible at App Store thumbnail size and does not promise features absent from version 1.
- [ ] Screens match the submitted build and current ReceiptSure brand.
- [ ] At least one screenshot demonstrates the core receipt-capture flow.
- [ ] Screenshots contain no alpha channel and meet Apple’s accepted pixel dimensions.
- [ ] The Pro review screenshot matches product ID `com.bodywiseremedy.receiptsure.pro.lifetime` and does not show a local StoreKit test environment banner.
- [ ] Save originals as `01-matters.png` through `06-export-backup.png`, plus `iap-receiptsure-pro.png`, in a private release-assets folder outside the public repository.
