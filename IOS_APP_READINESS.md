# ReceiptSure iOS readiness

## Repository stage

- Native SwiftUI source is committed independently from Bodywise Remedy.
- Xcode project generation is deterministic through `project.yml` and XcodeGen.
- GitHub Actions performs an unsigned iOS Simulator build on macOS.
- The app contains an opaque RGB 1024×1024 App Store icon, a required-reason privacy manifest, and camera/Face ID purpose strings.
- Version 1 targets iPhone only; an unsigned Release device archive is validated in GitHub Actions in addition to the Simulator build.
- Public privacy and support pages are included in the Vercel project and linked from the app’s Settings screen.
- Runtime dependencies are Apple-native; no third-party SDK is shipped.

## Functional stage

- Matter/trip/event creation
- VisionKit receipt scanning with automatic edge detection and crop
- Vision OCR with user correction before save
- SwiftData local persistence
- Search and date organization
- Totals by matter, category, date, and currency
- PDF, XLSX, CSV, DOCX, and JPG ZIP exports

## Owner-controlled release gates

1. Approve the final public app name and icon.
2. Select the Apple Developer team and register the final bundle identifier.
3. Verify the GitHub Actions build is green.
4. Build and test on physical iPhone hardware.
5. Merge and verify the production support and privacy-policy URLs.
6. Complete App Store metadata and privacy answers.
7. Archive in Xcode, upload to TestFlight, test, and submit.

The detailed sequence is in `RELEASE_CHECKLIST.md`, with exact App Store fields in `APP_STORE_CONNECT_SUBMISSION.md` and the capture plan in `APP_STORE_SCREENSHOTS.md`.
