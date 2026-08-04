# GitHub Actions iOS build

This repository follows the same public GitHub-to-iOS handoff pattern used for Bodywise Remedy.

The `iOS Build` workflow runs on every push and pull request to `main`, and can also be started manually from GitHub's Actions tab. It:

1. checks out the repository on a macOS runner;
2. installs XcodeGen;
3. generates `ReceiptArchive.xcodeproj` from `project.yml`; and
4. compiles the app for a generic iOS Simulator without code signing.

This catches Xcode-generation and Swift compilation failures on the current App Store toolchain. Camera scanning still needs a physical iPhone, and TestFlight/App Store uploads still require the owner's Apple Developer team, signing assets, final bundle identifier, and App Store Connect record.

## Reading a run

- A green run means the committed source generated and compiled on the hosted Mac.
- A red run should be opened and the failing `Generate Xcode project` or `Build for iOS Simulator` step inspected.
- The workflow does not upload builds, receipts, signing certificates, or provisioning profiles.

Do not commit Apple signing certificates, provisioning profiles, API keys, or App Store Connect private keys. Use GitHub encrypted secrets only if a later release workflow is intentionally added.
