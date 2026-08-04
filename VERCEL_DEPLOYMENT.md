# Vercel deployment trail

The interactive ReceiptSure preview is deployed from the same GitHub repository as the native SwiftUI app, with the two delivery paths kept separate.

## Connected project

- GitHub repository: `elaineq81/receipt-tracking-app`
- Vercel project: `justin-wei-hwa/receipt-tracking-app`
- Vercel root directory: `web-demo`
- Production branch: `main`
- Production URL: <https://receipt-tracking-app-lemon.vercel.app>

## Automatic behavior

- A push or merged pull request to `main` creates a Vercel production deployment from `web-demo/`.
- A pull request creates an isolated Vercel preview deployment for the proposed web-demo changes.
- The separate GitHub `iOS Build` workflow generates and compiles the native SwiftUI project on macOS.
- Changes outside `web-demo/` do not become web assets because Vercel's project root is explicitly scoped to that directory.

## Local deployment

Run Vercel commands from `web-demo/`, which is linked locally to the dedicated Vercel project. Local `.vercel` metadata and environment files are ignored by Git and must not be committed.
