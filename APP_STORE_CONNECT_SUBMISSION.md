# ReceiptSure App Store Connect submission sheet

Use this sheet when creating the next app in the owner’s Apple Developer and App Store Connect accounts. Values marked **owner decision** must be confirmed before the record is created or submitted.

## 1. Permanent app identity

| App Store Connect field | Prepared value |
| --- | --- |
| Platform | iOS |
| Name | ReceiptSure: Expense Proof |
| Primary language | English (U.S.) |
| Bundle ID | `com.bodywiseremedy.receiptsure` |
| SKU | `BWR-RECEIPTSURE-IOS-001` (suggested; internal and immutable) |
| User access | Full Access, unless the account has staff who should not see this app |
| Version | 1.0 |
| Build | 1 for the first upload; increment for every replacement upload |
| Primary category | Finance |
| Secondary category | Productivity |

Before creating the record, register the explicit bundle ID in Certificates, Identifiers & Profiles and confirm that the latest Apple agreements are signed. If this is the organization’s first app, carefully confirm the public developer name because Apple limits when it can be set or changed.

## 2. Public URLs

- Marketing URL: <https://receipt-tracking-app-lemon.vercel.app>
- Support URL: <https://receipt-tracking-app-lemon.vercel.app/support>
- Privacy policy URL: <https://receipt-tracking-app-lemon.vercel.app/privacy>

These pages are included in `web-demo/`. Confirm all three production URLs after this branch is merged to `main`; do not submit preview-deployment URLs to Apple.

## 3. Product-page copy

Use the subtitle, promotional text, description, and keywords in `APP_STORE_METADATA.md`. The prepared name, subtitle, and keyword field are within Apple’s limits.

Screenshot sequence and safe sample-data guidance are in `APP_STORE_SCREENSHOTS.md`.

## 4. App Privacy answers

For version 1, select **Data Not Collected**. Receipt images, OCR text, expense fields, device-lock preferences, and local backups are processed or stored on the device and are not transmitted to the developer. User-initiated sharing to a destination chosen in Apple’s system interface is not developer collection.

Reassess the answers before submission if any analytics, crash-reporting SDK, cloud sync, account, support upload, remote OCR, advertising, or server API is added.

## 5. Encryption and export compliance

ReceiptSure uses CryptoKit AES-GCM plus PBKDF2-HMAC-SHA256 to protect optional user-created backup archives. It does not currently operate a network service.

Do not guess the export-compliance result. In App Store Connect, open **App Information → App Encryption Documentation**, describe the standard encryption above, and complete Apple’s questionnaire. If Apple determines the use is exempt, set `ITSAppUsesNonExemptEncryption` to `NO` in `Info.plist` for later uploads. If documentation or a compliance code is required, obtain it first and add the code Apple provides. The key is intentionally absent from the current project until that determination is recorded.

## 6. Age rating and content declarations

Expected outcome: the lowest general age band. The app contains no violence, sexual content, profanity, drugs, gambling, contests, loot boxes, unrestricted web access, social networking, messaging, advertising, or public user-generated content. Complete Apple’s live questionnaire truthfully; its result is authoritative.

- Made for Kids: No
- Content rights: the app does not display or stream third-party catalog content
- Advertising identifier: not used
- In-app purchases/subscriptions: none in version 1
- Login: none

## 7. App Review information

Fill in the owner-controlled contact name, telephone number, and email. No demo account is required.

Suggested review note:

> ReceiptSure is an offline-first receipt organizer and requires no account. To test, create a matter, tap the camera button, scan a printed sample receipt, review the on-device OCR result, save it, and open Reports to export it. Camera access is used only for user-initiated VisionKit document scanning. Images and PDFs can also be selected through Apple system pickers. The app contains no analytics, advertising, tracking, or server upload. Optional secure backups are encrypted locally and shared only when the user chooses a destination.

## 8. Owner decisions before submission

- [ ] Confirm Apple Developer team and public developer/legal name.
- [ ] Confirm the SKU before creating the record; it cannot be changed afterward.
- [ ] Decide free or paid pricing.
- [ ] Select launch countries and regions.
- [ ] Supply App Review contact name, telephone, and email.
- [ ] Complete trademark clearance and reserve the accepted localized name.
- [ ] Complete Apple’s encryption questionnaire and record its result.
- [ ] Approve the final icon and screenshots.
- [ ] Complete physical-device and TestFlight release gates.

## 9. Upload route on the Mac

1. Install Xcode 26 or later with the iOS 26 SDK, plus XcodeGen, then run `xcodegen generate`.
2. Open `ReceiptArchive.xcodeproj`; the internal project and scheme names remain `ReceiptArchive`, while the shipped product is `ReceiptSure`.
3. Select the owner’s development team and confirm automatic signing resolves `com.bodywiseremedy.receiptsure`.
4. Select **Any iOS Device (arm64)** and choose **Product → Archive**.
5. In Organizer, run **Validate App**, then **Distribute App → App Store Connect → Upload**.
6. Wait for processing, attach build 1 to version 1.0, complete TestFlight information, and test before App Review submission.
