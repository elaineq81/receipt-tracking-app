# Receipt Archive iOS readiness

## Repository stage

- Native SwiftUI source is committed independently from Bodywise Remedy.
- Xcode project generation is deterministic through `project.yml` and XcodeGen.
- GitHub Actions performs an unsigned iOS Simulator build on macOS.
- The app contains an opaque 1024×1024 App Store icon, privacy manifest, and camera purpose string.
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
4. Build and test on physical iPhone/iPad hardware.
5. Publish the support and privacy-policy URLs.
6. Complete App Store metadata and privacy answers.
7. Archive in Xcode, upload to TestFlight, test, and submit.

The detailed sequence is in `RELEASE_CHECKLIST.md`.

