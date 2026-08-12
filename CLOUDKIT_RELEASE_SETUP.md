# ReceiptSure CloudKit production setup

TestFlight and App Store builds use the **Production** environment of `iCloud.com.receiptsure`. Creating the container and provisioning profile is necessary but does not deploy the record schema.

## Required production schema

In CloudKit Console, select `iCloud.com.receiptsure` and create this record type in the **Development** environment if it does not already exist:

| Record type | Field | Type |
| --- | --- | --- |
| `ReceiptSurePrivateLibrary` | `encryptedSnapshot` | Asset |
| `ReceiptSurePrivateLibrary` | `schemaVersion` | Int(64) |
| `ReceiptSurePrivateLibrary` | `updatedAt` | Date/Time |
| `ReceiptSurePrivateLibrary` | `deviceID` | String |

ReceiptSure stores one record in each user’s private database with record name `ReceiptSurePrivateLibrary`. The asset is already AES-GCM encrypted by the app before upload.

## Deploy and verify

1. Confirm the four fields above appear in the Development schema.
2. Choose **Deploy Schema Changes** and deploy them to Production.
3. Switch CloudKit Console to **Production** and confirm the record type and all four fields appear.
4. Install the TestFlight candidate on an iPhone signed in to iCloud with iCloud Keychain enabled.
5. In ReceiptSure, open **Settings → Private iCloud sync**, enable sync, and confirm “Last successful sync” appears.
6. On a second device using the same Apple Account, enable sync and verify records merge.
7. Test newest-edit conflict handling, permanent deletion, and **Delete iCloud copy** using the matrix in `RELEASE_CHECKLIST.md`.

Do not submit the app for review if the production schema is missing or any private-sync test fails. User records are private and won’t be visible in the developer portal; validate through the app on the user’s devices.
