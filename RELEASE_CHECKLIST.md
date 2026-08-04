# Xcode → TestFlight → App Store Connect checklist

## 1. Before the first archive

- [ ] Generate and open the Xcode project; confirm the iOS deployment target is 17.0.
- [ ] Set the final app name, unique bundle identifier, Apple Developer team, version, and build number.
- [ ] Review the included original 1024×1024 opaque AppIcon, confirm it as the final brand choice, and verify all appearance variants in Xcode.
- [ ] Decide whether the customer-facing name remains **Receipt Archive** and confirm trademark availability.
- [ ] Run on a physical iPhone: scan in bright, dim, skewed, long-receipt, and multi-page conditions.
- [ ] Verify OCR and manual correction with decimal commas, thousands separators, GST/VAT, and the target currencies.
- [ ] Open every export in its intended app: Preview/Files (PDF), Excel/Numbers (XLSX/CSV), Word/Pages (DOCX), and Files (JPG ZIP).
- [ ] Test Dynamic Type, VoiceOver labels, Dark Mode, landscape, iPad, low storage, cancel paths, and permission denial.
- [ ] Test deletion and confirm the associated receipt images are removed.
- [ ] Run Product → Analyze and resolve warnings; run the app with the Thread Sanitizer in a Debug build.
- [ ] Create a privacy-policy webpage and a support webpage; insert their public HTTPS URLs in App Store Connect.

## 2. App Store Connect record

- [ ] In Certificates, Identifiers & Profiles, register the exact bundle identifier.
- [ ] In App Store Connect → My Apps, create the iOS app record with that bundle ID and an SKU.
- [ ] Complete name, subtitle, category (Finance or Productivity), description, keywords, support URL, privacy-policy URL, copyright, and age-rating questionnaire.
- [ ] Complete App Privacy. For this local-only version, verify that data is not collected; reassess if analytics, cloud sync, support upload, or accounts are later added.
- [ ] Prepare localized iPhone/iPad screenshots from real app states without sample personal or financial data.
- [ ] Add review notes explaining: no login; scanning requires a physical camera; OCR runs on-device; exports are user initiated.

## 3. Archive and TestFlight

- [ ] In Xcode, select **Any iOS Device (arm64)**, then Product → Archive.
- [ ] In Organizer, Validate App, resolve signing/privacy issues, then Distribute App → App Store Connect → Upload.
- [ ] Wait for processing, answer export-compliance questions, and add TestFlight beta details.
- [ ] Test internally first. Confirm install, persistence after relaunch/update, camera permission copy, and every export on a clean device.
- [ ] Add external testers only after the beta review information and contact details are complete.
- [ ] Record known limitations and collect feedback without asking testers to share sensitive receipts unnecessarily.

## 4. Submission

- [ ] Increment the build number for every upload and select the final processed build on the app-version page.
- [ ] Reconfirm pricing/availability, content rights, privacy answers, encryption/export compliance, and release method.
- [ ] Submit for review and monitor App Review messages.
- [ ] After approval, use manual or phased release as appropriate and keep a rollback/support plan.

## Suggested App Review note

Receipt Archive is an offline-first receipt organizer. No account is required. To test, create a matter, tap the camera button, scan a printed sample receipt, review the on-device OCR result, save it, then open Reports to export it. Camera access is used only for user-initiated VisionKit document scanning. The app contains no analytics, advertising, tracking, or server upload.

## Not yet included

- Cloud sync, collaboration, automatic exchange-rate conversion, accounting-platform integrations, and encrypted backup are deliberately outside version 1.
- The included icon is technically ready, but the account owner must approve it as the final public brand asset.
- App Store metadata, legal URLs, signing credentials, and upload require the owner’s Apple Developer account and cannot be completed from a Windows workspace.
