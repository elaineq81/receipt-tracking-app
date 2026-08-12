# Xcode → TestFlight → App Store Connect checklist

## 1. Before the first archive

- [ ] Generate and open the Xcode project; confirm the iOS deployment target is 17.0.
- [ ] Confirm version 1 is intentionally iPhone-only and remove any unplanned iPad availability from the product record.
- [ ] Set the final app name, unique bundle identifier, Apple Developer team, version, and build number.
- [ ] Confirm Xcode resolves Apple team `B5DJ69S32C`, version `1.0`, build `1`, and bundle ID `com.bodywiseremedy.receiptsure` before the first signed archive.
- [ ] Review the included original 1024×1024 opaque AppIcon, confirm it as the final brand choice, and verify all appearance variants in Xcode.
- [ ] Reserve **ReceiptSure: Expense Proof** in App Store Connect and complete professional trademark clearance for ReceiptSure in every intended launch market.
- [ ] Run on a physical iPhone: scan in bright, dim, skewed, long-receipt, and multi-page conditions.
- [ ] Verify OCR and manual correction with decimal commas, thousands separators, GST/VAT, and the target currencies.
- [ ] Open every export in its intended app: Preview/Files (PDF), Excel/Numbers (XLSX/CSV), Word/Pages (DOCX), and Files (JPG ZIP).
- [ ] Test Dynamic Type, VoiceOver labels, Dark Mode, landscape, small and large supported iPhones, low storage, cancel paths, and permission denial.
- [ ] Test deletion and confirm the associated receipt images are removed.
- [ ] On physical devices with and without Face ID, verify device-owner authentication, passcode fallback, cancellation, relocking after backgrounding, and recovery after failed authentication.
- [ ] Confirm receipt content is absent from app-switcher snapshots whenever privacy shielding is enabled.
- [ ] Create a secure archive with a strong test password, restore it into a clean installation, and compare matter, receipt, image, revision, rule, and financial-provenance counts.
- [ ] Verify wrong-password and modified-archive failures, duplicate-skipping on a second restore, a 20-page receipt backup, low-storage behavior, and interruption during export/import.
- [ ] Save the archive through Files and at least one third-party document provider, then reopen it through the registered `.receiptarchive` file type.
- [ ] Run Product → Analyze and resolve warnings; run the app with the Thread Sanitizer in a Debug build.
- [ ] Create a privacy-policy webpage and a support webpage; insert their public HTTPS URLs in App Store Connect.
- [ ] Confirm the bundled privacy manifest declares app-only UserDefaults access with approved reason `CA92.1`.
- [ ] Run the local `ReceiptSure.storekit` purchase flow: buy, cancel, pending approval, restore, delete local transaction, and refund/revocation.

## 2. App Store Connect record

- [ ] In Certificates, Identifiers & Profiles, register the exact bundle identifier.
- [x] Enable iCloud/CloudKit for the App ID, attach `iCloud.com.receiptsure`, and install a matching App Store provisioning profile.
- [ ] Deploy the `ReceiptSurePrivateLibrary` record schema to the CloudKit Production environment using `CLOUDKIT_RELEASE_SETUP.md`.
- [ ] In App Store Connect → My Apps, create the iOS app record with that bundle ID and an SKU.
- [ ] Complete name, subtitle, category (Finance or Productivity), description, keywords, support URL, privacy-policy URL, copyright, and age-rating questionnaire.
- [ ] Use `APP_STORE_CONNECT_SUBMISSION.md` for permanent identifiers, App Privacy, encryption, review notes, and owner-controlled decisions.
- [ ] Complete App Privacy from the final binary. The prepared answer remains **Data Not Collected** because private-sync content is stored only in the user’s private CloudKit database and is not accessible to the developer; reassess if developer-accessible storage, analytics, support upload, accounts, or third-party collection is added.
- [ ] Prepare iPhone screenshots from real app states using `APP_STORE_SCREENSHOTS.md`; do not use the browser preview as a submitted screenshot.
- [ ] Add review notes explaining: no login; scanning requires a physical camera; OCR runs on-device; exports are user initiated.
- [ ] Create the non-consumable **ReceiptSure Pro Lifetime** product with ID `com.bodywiseremedy.receiptsure.pro.lifetime`, choose the closest Singapore price point to S$59.98, localize it, and attach its review screenshot.
- [ ] Add the first non-consumable to the same version 1.0 review submission; Apple requires the first product of that type to accompany a new app version.
- [ ] Verify the IAP localized description is no more than 45 characters and use: **Unlimited receipts, reports, and exports.**
- [ ] Complete EU DSA trader status and any required public-contact verification before enabling EU storefronts; enable all other eligible territories requested by the owner.
- [ ] Complete the current age-rating flow and save Apple’s calculated global and regional results.
- [ ] Test all common tasks with each proposed accessibility feature before publishing the iPhone Accessibility Nutrition Label.

## 3. Archive and TestFlight

- [ ] In Xcode, select **Any iOS Device (arm64)**, then Product → Archive.
- [ ] In Organizer, Validate App, resolve signing/privacy issues, then Distribute App → App Store Connect → Upload.
- [ ] Confirm the final source still uses only Apple CryptoKit/Security cryptography and that the archive contains `ITSAppUsesNonExemptEncryption = NO`; reassess if another cryptographic implementation is added.
- [ ] Wait for processing, resolve any export-compliance prompt against the actual binary, and add TestFlight beta details.
- [ ] Test internally first. Confirm install, persistence after relaunch/update, camera permission copy, and every export on a clean device.
- [ ] With a sandbox Apple Account, verify the free allowances, purchase, cancellation, Ask to Buy/pending state, entitlement persistence, Restore Purchases, Family Sharing choice, and refund/revocation behavior.
- [ ] Add external testers only after the beta review information and contact details are complete.
- [ ] Record known limitations and collect feedback without asking testers to share sensitive receipts unnecessarily.

## 4. Submission

- [ ] Increment the build number for every upload and select the final processed build on the app-version page.
- [ ] Reconfirm pricing/availability, content rights, privacy answers, encryption/export compliance, and release method.
- [ ] Confirm manual release is selected for version 1 so approval does not publish before support and launch readiness are confirmed.
- [ ] Submit for review and monitor App Review messages.
- [ ] After approval, use manual or phased release as appropriate and keep a rollback/support plan.

## Physical-iPhone validation record — version 1.0 builds 3–4

Build 3 was signed and uploaded to App Store Connect on 12 August 2026. GitHub Actions run: https://github.com/elaineq81/receipt-tracking-app/actions/runs/31553071883. Apple delivery ID: `5d620bc8-bed8-485c-8900-b625c441feb3`.

Record the iPhone model, iOS version, tester, date, and each result before starting the iCloud/data-model development tranche. Use **Pass**, **Fail**, or **Blocked**, and add a short reproduction note for every failure.

| Test | Result | Notes |
| --- | --- | --- |
| Clean install opens, onboarding completes, and no blank or placeholder branding appears | Pending | |
| Updating from the previous TestFlight build preserves matters, receipts, images, revisions, and totals | Pass | Verified on build 4. |
| Camera permission allow, deny, and later-enable paths behave clearly | Pending | |
| Bright, dim, skewed, long, and multi-page receipts scan and crop correctly | Pass | Core real-receipt scan and automatic crop passed on build 4; retain edge-condition coverage before submission. |
| Manual recrop corrects all four corners and re-running OCR updates the reviewed draft | Pass | Verified on build 4. |
| Merchant, date, currency, total, tax, and category can be corrected and saved | Pass | Verified on build 4. |
| Decimal-comma, thousands-separator, GST/VAT, and non-USD examples produce correct values | Pending | |
| Share sheet sends a receipt image/PDF to Messages and saves it to Files without exposing another receipt | Pass | Messages and Files sharing verified on build 4. |
| PDF, XLSX, CSV, DOCX, JPG bundle, and Proof Pack exports open in their intended apps and totals match | Partial | PDF and CSV verified on build 4; advanced formats remain pending. |
| Recently Deleted restores a receipt and permanent deletion removes its stored image | Pending | |
| Face ID/passcode unlock, cancellation, failed authentication, background relock, and app-switcher shielding work | Pass | Face ID loop fixed in build 4 and verified on a physical iPhone. |
| Encrypted backup restores into a clean installation; wrong password, duplicate restore, and modified archive fail safely | Pending | |
| Free allowance, purchase, cancel/pending, entitlement persistence, Restore Purchases, and refund/revocation paths behave correctly | Pending | |
| Offline launch, save, relaunch, search, report, and export work without network access | Partial | Relaunch and persistence passed; complete the full no-network matrix before submission. |
| VoiceOver, Larger Text, Dark Mode, Reduce Motion, landscape, and a small supported iPhone keep common tasks usable | Pending | |
| Rapid scrolling and a representative large receipt library remain responsive without visible data loss or crashes | Pending | |
| Private sync is off by default; enabling it creates the encrypted snapshot and a second device merges new records | Pending | Build 5 candidate. |
| Newer same-record edits win across two devices for receipts, merchant rules, and custom categories | Pending | Build 5 candidate. |
| Permanent receipt deletion propagates through a deletion marker and does not resurrect on the second device | Pending | Build 5 candidate. |
| Turning private sync off stops automatic syncing; “Delete iCloud copy” removes the cloud snapshot but preserves local receipts | Pending | Build 5 candidate. |
| Batch capture saves multiple independently reviewable receipts without lost or duplicated pages | Pending | Build 5 candidate. |
| Spanish and Simplified Chinese core capture, settings, categories, and sync screens fit without clipped controls | Pending | Build 5 candidate. |

Gate decision: **Core baseline passed on build 4**. The iCloud/data-model tranche may proceed. Do not submit for App Review until every remaining Pending/Partial row is resolved on the final candidate build.

## Suggested App Review note

ReceiptSure is an offline-first receipt organizer. No ReceiptSure account is required. Optional private iCloud sync is off by default and stores an AES-GCM encrypted library snapshot only in the user’s private CloudKit database; the developer operates no receipt-data server. The free plan includes 15 stored receipts, two matters, one PDF report, and CSV export. ReceiptSure Pro is the one-time non-consumable product `com.bodywiseremedy.receiptsure.pro.lifetime`; it unlocks unlimited creation, reports, advanced exports, and merchant rules. Existing data remains accessible without purchase. Restore Purchases is available in Settings and on the Pro screen. Camera access is used only for user-initiated VisionKit scanning. The app contains no analytics, advertising, or tracking.

## Not yet included

- Collaboration, automatic exchange-rate lookup, and accounting-platform integrations remain outside version 1. Encrypted backup and optional private iCloud sync are included but must pass the physical-device tests above before release.
- The included icon is technically ready, but the account owner must approve it as the final public brand asset.
- App Store account fields, signing credentials, production screenshots, encryption determination, and upload require the owner’s Apple Developer account and a Mac with Xcode.
