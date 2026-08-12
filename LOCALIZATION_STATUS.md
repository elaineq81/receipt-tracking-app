# ReceiptSure localization status

ReceiptSure uses English as its source language. Xcode currently inventories 313 localizable units: 308 interface strings and 5 app-name/permission strings.

## Current tranche

| Locale | Draft coverage | Reviewed coverage | Release status |
|---|---:|---:|---|
| English | 313/313 | Source language | Baseline |
| Spanish (Spain) | 313/313 | Navigation, capture, backup, privacy, sync, permissions, categories | Blocked pending full linguistic and layout review |
| Spanish (Mexico) | 313/313 | Navigation, capture, backup, privacy, sync, permissions, categories | Blocked pending regional and layout review |
| Chinese (Simplified) | 313/313 | Navigation, capture, backup, privacy, sync, permissions, categories | Blocked pending full linguistic and layout review |
| Chinese (Traditional) | 313/313 | Navigation, capture, backup, privacy, sync, permissions, categories | Blocked pending full linguistic and layout review |

All other configured App Store languages remain pending. Machine-assisted values use the String Catalog state `needs_review`; the release validator only accepts `translated`. Placeholders such as `%@` and `%lld` must remain byte-for-byte identical.

## Required release sampling

- Spanish (Mexico and Spain): terminology, truncation, long privacy and backup explanations.
- Arabic, Hebrew, and Urdu: right-to-left navigation, numbers, currency, crop handles, and share sheets.
- Simplified and Traditional Chinese, Japanese, and Korean: line breaks and compact controls.
- Hindi, Bangla, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, and Telugu: font fallback, line height, Dynamic Type, and numerals.
- French, German, Finnish, Russian, and Ukrainian: long-label truncation and report/export terminology.

Do not select a replacement TestFlight build for App Review until the strict validator and representative device matrix pass.
