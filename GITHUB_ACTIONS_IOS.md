# GitHub Actions iOS build

This repository follows the same public GitHub-to-iOS handoff pattern used for Bodywise Remedy.

The `iOS Build` workflow runs on every push and pull request to `main`, and can also be started manually from GitHub's Actions tab. It:

1. checks out the repository on a macOS runner;
2. installs XcodeGen;
3. generates `ReceiptArchive.xcodeproj` from `project.yml`; and
4. compiles the app for a generic iOS Simulator without code signing;
5. creates an unsigned Release archive; and
6. verifies the bundle identity, iPhone-only device family, privacy manifest, purpose strings, and export-compliance key.

This catches Xcode-generation and Swift compilation failures on the current App Store toolchain. Camera scanning still needs a physical iPhone, and TestFlight/App Store uploads still require the owner's Apple Developer team, signing assets, final bundle identifier, and App Store Connect record.

## Reading a run

- A green run means the committed source generated and compiled on the hosted Mac.
- A red run should be opened and the failing `Generate Xcode project` or `Build for iOS Simulator` step inspected.
- The normal `iOS Build` workflow does not upload builds, receipts, signing certificates, or provisioning profiles.

## Manual TestFlight upload

`ReceiptSure TestFlight Upload` is a separate manual-only workflow. It runs only when an operator supplies a build number and explicitly selects **Upload this build to TestFlight**. It validates the project, creates a signed App Store archive, verifies the signed bundle, exports the IPA, and uploads it to App Store Connect. It never adds the build or in-app purchase for review and never presses Submit for Review.

Required encrypted repository secrets:

- `APPSTORE_KEY_ID`
- `APPSTORE_ISSUER_ID`
- `APPSTORE_PRIVATE_KEY`
- `APPLE_TEAM_ID`

Automatic signing is attempted when the optional manual-signing secrets are absent. If automatic signing is not permitted for the API key, create a new App Store provisioning profile for `com.bodywiseremedy.receiptsure` and add:

- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISION_PROFILE_BASE64`

Do not reuse Bodywise’s provisioning profile: it belongs to a different bundle identifier. A distribution certificate may be usable across apps on the same team, but it must still be supplied through ReceiptSure’s own encrypted repository secrets.

`App Store preflight audit` is read-only. Once the API secrets exist, it checks version 1.0 metadata, URLs, App Review contact completeness, build processing, and the build’s export-compliance flag without changing App Store Connect.

Do not commit Apple signing certificates, provisioning profiles, API keys, or App Store Connect private keys. Store them only as GitHub encrypted secrets and restrict who can run the upload environment.
