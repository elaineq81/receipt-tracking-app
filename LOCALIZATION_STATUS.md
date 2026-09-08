# ReceiptSure localization status

ReceiptSure uses English as its source language. Xcode currently inventories 333 localizable units: 328 interface strings and 5 app-name/permission strings.

## Current tranche

| Locale | Draft coverage | Reviewed coverage | Release status |
|---|---:|---:|---|
| English | 333/333 | Source language | Baseline |
| Spanish (Spain) | 333/333 | 333/333 | Catalog complete; pending final device sampling |
| Spanish (Mexico) | 333/333 | 333/333 | Catalog complete; pending final regional device sampling |
| Chinese (Simplified) | 333/333 | 100/333 | Blocked pending full linguistic and layout review |
| Chinese (Traditional) | 333/333 | 49/333 | Blocked pending full linguistic and layout review |
| French | 333/333 | 34/333 | Blocked pending full linguistic and layout review |
| French (Canada) | 333/333 | 34/333 | Blocked pending regional and layout review |
| German | 333/333 | 34/333 | Blocked pending full linguistic and layout review |
| Japanese | 333/333 | 34/333 | Blocked pending full linguistic and layout review |
| Korean | 333/333 | 34/333 | Blocked pending full linguistic and layout review |
| Portuguese (Brazil) | 333/333 | 34/333 | Blocked pending regional and layout review |
| Portuguese (Portugal) | 333/333 | 34/333 | Blocked pending regional and layout review |
| Arabic | 333/333 | 34/333 | Blocked pending full linguistic and RTL layout review |
| Hebrew | 333/333 | 34/333 | Blocked pending full linguistic and RTL layout review |
| Urdu | 333/333 | 34/333 | Blocked pending full linguistic and RTL layout review |

The remaining 32 configured non-English locales have not yet been populated. Machine-assisted values use the String Catalog state `needs_review`; the release validator only accepts `translated`. Placeholders such as `%@` and `%lld` must remain byte-for-byte identical. The strict gate currently reports 14,195 gaps. Run `python scripts/localization-report.py` for the current per-locale counts.

## Required release sampling

- Spanish (Mexico and Spain): terminology, truncation, long privacy and backup explanations.
- Arabic, Hebrew, and Urdu: right-to-left navigation, numbers, currency, crop handles, and share sheets.
- Simplified and Traditional Chinese, Japanese, and Korean: line breaks and compact controls.
- Hindi, Bangla, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, and Telugu: font fallback, line height, Dynamic Type, and numerals.
- French, German, Finnish, Russian, and Ukrainian: long-label truncation and report/export terminology.

Do not select a replacement TestFlight build for App Review until the strict validator and representative device matrix pass.

The `ReceiptSure Localization Smoke Test` workflow launches the Settings and Matters interfaces in thirteen representative locales and retains 26 genuine simulator screenshots for visual review, including Arabic, Hebrew, and Urdu right-to-left layouts. Its first visual review exposed mixed-language and missing-space defects in the shared Settings surface. The corrected run passed and the representative Settings layouts were manually rechecked; long-content scrolling and the complete capture/report flows still require physical-device sampling.
