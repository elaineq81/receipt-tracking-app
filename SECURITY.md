# ReceiptArchive security model

## Local protection

ReceiptArchive stores receipts in the app’s private container. Users can require Apple device-owner authentication, which permits Face ID, Touch ID, or device-passcode fallback. When privacy shielding is enabled, receipt content is replaced before the app becomes inactive so it does not appear in the app switcher snapshot.

The app lock is a privacy boundary inside an already unlocked device. It is not a substitute for a device passcode, operating-system updates, or full-device data protection.

## Secure archive format

The `.receiptarchive` file is a versioned, full-library archive containing matters, receipts, images, OCR text, verification state, revision history, financial provenance, and merchant rules.

- Encryption: AES-256-GCM authenticated encryption through Apple CryptoKit.
- Key derivation: PBKDF2-HMAC-SHA256, 100,000 iterations, one 256-bit block.
- Salt: a unique 128-bit cryptographically secure random salt per archive.
- Password handling: the password and derived key are never persisted.
- Integrity: AES-GCM authentication rejects altered archives and incorrect passwords.
- Restore policy: merge-only. Existing receipt and rule identifiers are skipped; current records are never deleted.

The archive is only as resistant to password guessing as the password chosen by the user. A unique, high-entropy password stored in a password manager is recommended. Forgotten passwords cannot be recovered.

## Current boundaries

- Archives are user-initiated rather than automatically synchronized.
- The backup-health indicator records archive creation, not whether the user completed the share/save action.
- The project requires restore-fixture and device lifecycle tests before App Store release.
- Security issues should be reported privately to the repository owner rather than opened with sensitive sample data in a public issue.
