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
- [ ] In App Store Connect → My Apps, create the iOS app record with that bundle ID and an SKU.
- [ ] Complete name, subtitle, category (Finance or Productivity), description, keywords, support URL, privacy-policy URL, copyright, and age-rating questionnaire.
- [ ] Use `APP_STORE_CONNECT_SUBMISSION.md` for permanent identifiers, App Privacy, encryption, review notes, and owner-controlled decisions.
- [ ] Complete App Privacy. For this local-only version, verify that data is not collected; reassess if analytics, cloud sync, support upload, or accounts are later added.
- [ ] Prepare iPhone screenshots from real app states using `APP_STORE_SCREENSHOTS.md`; do not use the browser preview as a submitted screenshot.
- [ ] Add review notes explaining: no login; scanning requires a physical camera; OCR runs on-device; exports are user initiated.
- [ ] Create the non-consumable **ReceiptSure Pro Lifetime** product with ID `com.bodywiseremedy.receiptsure.pro.lifetime`, choose the closest Singapore price point to S$59.98, localize it, and attach its review screenshot.
- [ ] Add the first non-consumable to the same version 1.0 review submission; Apple requires the first product of that type to accompany a new app version.
- [ ] Verify the IAP localized description is no more than 45 characters and use: **Unlimited receipts, reports, and exports.**
- [ ] Complete EU DSA trader status. Keep EU storefronts out of the initial availability until any required verification is complete.
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

## Suggested App Review note

ReceiptSure is an offline-first receipt organizer. No account is required. The free plan includes 15 stored receipts, two matters, one PDF report, and CSV export. ReceiptSure Pro is the one-time non-consumable product `com.bodywiseremedy.receiptsure.pro.lifetime`; it unlocks unlimited creation, reports, advanced exports, and merchant rules. Existing data remains accessible without purchase. Restore Purchases is available in Settings and on the Pro screen. Camera access is used only for user-initiated VisionKit scanning. The app contains no analytics, advertising, tracking, or server upload.

## Not yet included

- Cloud sync, collaboration, automatic exchange-rate lookup, and accounting-platform integrations remain outside version 1. Encrypted backup is included but must pass the physical-device round-trip tests above before release.
- The included icon is technically ready, but the account owner must approve it as the final public brand asset.
- App Store account fields, signing credentials, production screenshots, encryption determination, and upload require the owner’s Apple Developer account and a Mac with Xcode.
