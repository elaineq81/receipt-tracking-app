# ReceiptSure localization status

ReceiptSure uses English as its source language. Xcode currently inventories 333 localizable units: 328 interface strings and 5 app-name/permission strings.

## Current tranche

| Locale | Draft coverage | Reviewed coverage | Release status |
|---|---:|---:|---|
| English | 333/333 | Source language | Baseline |
| Spanish (Spain) | 333/333 | 92/333 | Blocked pending full linguistic and layout review |
| Spanish (Mexico) | 333/333 | 92/333 | Blocked pending regional and layout review |
| Chinese (Simplified) | 333/333 | 92/333 | Blocked pending full linguistic and layout review |
| Chinese (Traditional) | 333/333 | 39/333 | Blocked pending full linguistic and layout review |
| French | 333/333 | 21/333 | Blocked pending full linguistic and layout review |
| French (Canada) | 333/333 | 21/333 | Blocked pending regional and layout review |
| German | 333/333 | 21/333 | Blocked pending full linguistic and layout review |
| Japanese | 333/333 | 21/333 | Blocked pending full linguistic and layout review |
| Korean | 333/333 | 21/333 | Blocked pending full linguistic and layout review |
| Portuguese (Brazil) | 333/333 | 21/333 | Blocked pending regional and layout review |
| Portuguese (Portugal) | 333/333 | 21/333 | Blocked pending regional and layout review |

The remaining 35 configured non-English locales have not yet been populated. Machine-assisted values use the String Catalog state `needs_review`; the release validator only accepts `translated`. Placeholders such as `%@` and `%lld` must remain byte-for-byte identical. Run `python scripts/localization-report.py` for the current per-locale counts.

## Required release sampling

- Spanish (Mexico and Spain): terminology, truncation, long privacy and backup explanations.
- Arabic, Hebrew, and Urdu: right-to-left navigation, numbers, currency, crop handles, and share sheets.
- Simplified and Traditional Chinese, Japanese, and Korean: line breaks and compact controls.
- Hindi, Bangla, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, and Telugu: font fallback, line height, Dynamic Type, and numerals.
- French, German, Finnish, Russian, and Ukrainian: long-label truncation and report/export terminology.

Do not select a replacement TestFlight build for App Review until the strict validator and representative device matrix pass.

The `ReceiptSure Localization Smoke Test` workflow launches the Settings and Matters interfaces in ten representative locales and retains 20 genuine simulator screenshots for visual review.
