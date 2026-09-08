# ReceiptSure localization status

ReceiptSure uses English as its source language. Xcode currently inventories 334 localizable units: 329 interface strings and 5 app-name/permission strings.

## Current tranche

| Locale | Draft coverage | Reviewed coverage | Release status |
|---|---:|---:|---|
| English | 334/334 | Source language | Baseline |
| Spanish (Spain) | 334/334 | 334/334 | Catalog complete; pending final device sampling |
| Spanish (Mexico) | 334/334 | 334/334 | Catalog complete; pending final regional device sampling |
| Chinese (Simplified) | 334/334 | 334/334 | Catalog complete; pending final device sampling |
| Chinese (Traditional) | 334/334 | 49/334 | Blocked pending full linguistic and layout review |
| French | 334/334 | 34/334 | Blocked pending full linguistic and layout review |
| French (Canada) | 334/334 | 34/334 | Blocked pending regional and layout review |
| German | 334/334 | 34/334 | Blocked pending full linguistic and layout review |
| Japanese | 334/334 | 34/334 | Blocked pending full linguistic and layout review |
| Korean | 334/334 | 34/334 | Blocked pending full linguistic and layout review |
| Portuguese (Brazil) | 334/334 | 34/334 | Blocked pending regional and layout review |
| Portuguese (Portugal) | 334/334 | 34/334 | Blocked pending regional and layout review |
| Arabic | 334/334 | 34/334 | Blocked pending full linguistic and RTL layout review |
| Hebrew | 334/334 | 34/334 | Blocked pending full linguistic and RTL layout review |
| Urdu | 334/334 | 34/334 | Blocked pending full linguistic and RTL layout review |

The remaining 32 configured non-English locales have not yet been populated. Machine-assisted values use the String Catalog state `needs_review`; the release validator only accepts `translated`. Placeholders such as `%@` and `%lld` must remain byte-for-byte identical. The strict gate currently reports 14,005 gaps. Run `python scripts/localization-report.py` for the current per-locale counts.

The Matters list now uses separate localized singular and plural receipt-count strings. This replaces the earlier English-only `"s"` suffix construction, which could not render correctly in Chinese, Japanese, Korean, Arabic, Hebrew, or Urdu.

## Required release sampling

- Spanish (Mexico and Spain): terminology, truncation, long privacy and backup explanations.
- Arabic, Hebrew, and Urdu: right-to-left navigation, numbers, currency, crop handles, and share sheets.
- Simplified and Traditional Chinese, Japanese, and Korean: line breaks and compact controls.
- Hindi, Bangla, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, and Telugu: font fallback, line height, Dynamic Type, and numerals.
- French, German, Finnish, Russian, and Ukrainian: long-label truncation and report/export terminology.

Do not select a replacement TestFlight build for App Review until the strict validator and representative device matrix pass.

The `ReceiptSure Localization Smoke Test` workflow launches the Settings and Matters interfaces in thirteen representative locales and retains 26 genuine simulator screenshots for visual review, including Arabic, Hebrew, and Urdu right-to-left layouts. Its first visual review exposed mixed-language and missing-space defects in the shared Settings surface. The corrected run passed and the representative Settings layouts were manually rechecked; long-content scrolling and the complete capture/report flows still require physical-device sampling.
