# ReceiptSure Apple account handoff

This is the account-side execution sheet for ReceiptSure version 1.0. Complete it in order. Do not upload a signed build until the permanent app identity and encryption determination are attached to the same Apple Developer team.

## 1. Apple Developer identity

Register an **explicit App ID** in Certificates, Identifiers & Profiles.

| Field | Value |
| --- | --- |
| Description | ReceiptSure iOS |
| Bundle ID type | Explicit |
| Bundle ID | `com.bodywiseremedy.receiptsure` |
| Required capability | In-App Purchase (enabled by default for an explicit App ID) |
| Unneeded for version 1 | iCloud, Sign in with Apple, Push Notifications, Associated Domains |

In Xcode, assign the `ReceiptArchive` target to the same paid Apple Developer team and retain automatic signing. Do not change the bundle ID after the App Store Connect record is created.

Record the selected values here:

| Owner-controlled field | Final value |
| --- | --- |
| Legal developer/account name | **Required from owner** |
| Apple Developer Team name | **Required from signed-in account** |
| Team ID | **Required from signed-in account** |

## 2. App Store Connect record

Create the app only after the explicit Bundle ID appears in App Store Connect.

| Field | Prepared value |
| --- | --- |
| Platform | iOS |
| Name | ReceiptSure: Expense Proof |
| Primary language | English (U.S.) |
| Bundle ID | `com.bodywiseremedy.receiptsure` |
| SKU | `BWR-RECEIPTSURE-IOS-001` |
| User access | Full Access |
| Primary category | Finance |
| Secondary category | Productivity |
| App price | Free |

Successful creation reserves the localized name in that account and changes the app status to **Prepare for Submission**. If Apple rejects the name as unavailable, stop before creating a differently named record so the public brand, metadata, and bundle trail can be updated together.

## 3. ReceiptSure Pro Lifetime

The Account Holder must accept the current Paid Apps Agreement and complete tax and banking setup before paid content can be sold.

| Field | Prepared value |
| --- | --- |
| Type | Non-Consumable |
| Reference name | ReceiptSure Pro Lifetime |
| Product ID | `com.bodywiseremedy.receiptsure.pro.lifetime` |
| Base country or region | Singapore |
| Target customer price | Closest selectable Apple price point to S$59.98 |
| Display name | ReceiptSure Pro Lifetime |
| Description | Unlimited receipts, matters, reports, professional exports, and merchant filing rules. |
| Family Sharing | Off for version 1; reconsider before submission because enabling it later is a product-policy decision |

Use Apple’s automatic equivalent pricing for other storefronts. Do not hard-code regional prices in metadata or screenshots; the app displays StoreKit’s localized price.

## 4. Recommended launch availability

Use a controlled English-language first wave:

- Singapore
- Australia
- Canada
- Ireland
- New Zealand
- United Kingdom
- United States

Do not automatically include future storefronts in version 1. This gives support and privacy materials one language, keeps the Singapore base price intentional, and still covers a meaningful market. Expand after the first release is stable and metadata is localized. The app contains no country-specific tax advice.

## 5. Export-compliance submission

ReceiptSure uses encryption for an optional user-created backup archive:

- Apple CryptoKit `AES.GCM` for authenticated encryption.
- A 256-bit key derived from the user’s password using PBKDF2-style HMAC-SHA256 with a random 16-byte salt and 100,000 iterations.
- `SecRandomCopyBytes` for salt generation.
- Local encryption and decryption only; no developer server receives the archive, password, key, or receipt data.
- No proprietary or unpublished cryptographic algorithm.

In **App Information → App Encryption Documentation**, answer the live questionnaire according to those facts. The app does use encryption. It uses standard algorithms and Apple cryptographic APIs, and it performs password-based protection of user data at rest. Do not select “no encryption” merely because CryptoKit supplies AES-GCM.

Allow Apple’s questionnaire to determine whether an exemption applies or documentation is required. If Apple requests documentation, upload it before TestFlight external review or App Review. If Apple approves documentation and supplies a compliance key, add that exact value to the app’s Info.plist. If Apple determines the app is exempt, record the result and only then add the exemption value Apple instructs. Preserve a screenshot/PDF of the result in the private release records; do not commit owner or account identifiers to this public repository.

## 6. Private App Review contact

These details are required in App Store Connect but must not be committed to the public repository:

| Field | Required value |
| --- | --- |
| First and last name | **Required from owner** |
| Email | **Required from owner** |
| Phone with country code | **Required from owner** |
| Sign-in required | No |
| Demo account | Not applicable |

Use the prepared review note in `APP_STORE_CONNECT_SUBMISSION.md`. The public support URL is `https://receipt-tracking-app-lemon.vercel.app/support` and the privacy URL is `https://receipt-tracking-app-lemon.vercel.app/privacy`.

## 7. Signed archive and TestFlight gate

On a Mac with Xcode 26 or later:

1. Clone `https://github.com/elaineq81/receipt-tracking-app.git` and check out `main`.
2. Install XcodeGen and run `xcodegen generate`.
3. Open `ReceiptArchive.xcodeproj`, select the owner’s paid team, and confirm automatic signing resolves the exact bundle ID.
4. Run on a physical iPhone and complete the capture, import, OCR, correction, backup/restore, purchase, and export test matrix in `RELEASE_CHECKLIST.md`.
5. Select **Any iOS Device (arm64)** and choose **Product → Archive**.
6. In Organizer, choose **Validate App**. Resolve every signing, privacy, icon, and export-compliance issue.
7. Choose **Distribute App → App Store Connect → Upload**, keep symbol upload enabled, and use automatic signing.
8. Wait for processing, attach the build to internal TestFlight, and complete clean-install and update tests on a physical iPhone before inviting external testers.

The repository’s hosted Mac workflow already verifies project generation, Simulator compilation, an unsigned Release archive, and release-bundle contents. It does not replace signing, camera testing, sandbox purchases, or physical-device validation.
