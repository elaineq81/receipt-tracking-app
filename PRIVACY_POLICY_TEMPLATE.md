# ReceiptSure Privacy Policy (template)

**Effective date:** [DATE]  
**Developer:** [LEGAL NAME]  
**Contact:** [SUPPORT EMAIL]

ReceiptSure helps users scan, organize, and export receipt and expense records. Receipt text is processed on the device. Receipt images and expense details remain in the app’s private local storage unless the user enables private iCloud sync.

## Data handling

ReceiptSure does not transmit receipt images, extracted text, expense data, or identifiers to the developer. It does not include a ReceiptSure account, advertising, analytics, tracking, a developer server, or third-party data-collection SDKs. Except for private iCloud sync that the user explicitly enables, data leaves the app only when the user deliberately exports, backs up, or shares a file using Apple’s system interfaces; the privacy practices of the selected destination then apply. Optional secure archives are encrypted locally with a password-derived key, and the password is not stored by ReceiptSure.

## Optional private iCloud sync

Private iCloud sync is off by default. If enabled, ReceiptSure encrypts a snapshot of the library—including receipt images and expense details—on the device using AES-GCM and stores it in the user’s private Apple CloudKit database. The encryption key is stored through iCloud Keychain for the user’s devices signed in to the same Apple Account. The developer does not receive the snapshot or key and cannot browse the user’s private database through the app. Apple’s handling is governed by the user’s Apple Account settings and Apple’s terms and privacy policy.

## Camera and photos

Camera access is requested only when the user starts a receipt scan. Apple VisionKit is used to detect and crop the document. Image and PDF imports use Apple’s system pickers, which provide only the files selected by the user.

## Retention and deletion

Local records remain until the user deletes them or removes the app. Files that the user exports or backs up remain wherever the user chose to save or share them. Device backups may be handled by the user’s Apple and device settings. Turning private sync off stops future synchronization. “Delete iCloud copy” removes ReceiptSure’s current encrypted cloud snapshot while keeping local receipts; another device with sync still enabled may upload its library again.

## Purchases

ReceiptSure Pro is purchased through Apple’s App Store. ReceiptSure uses Apple StoreKit to display the localized price, complete the purchase, verify the entitlement, and restore it. The developer does not receive or store payment-card details. Apple’s handling of purchase and account information is governed by Apple’s privacy policy and the user’s App Store settings.

## Changes and contact

This policy will be updated when ReceiptSure’s data practices materially change. Questions can be sent to [SUPPORT EMAIL].

> Replace every bracketed placeholder, have the final policy reviewed for the markets where the app is distributed, and publish it at a stable public HTTPS URL before App Store submission.
