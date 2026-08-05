import SwiftUI

struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason

    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(.teal)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(reason.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(reason.detail)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        benefit("Unlimited receipts and matters", symbol: "doc.on.doc.fill")
                        benefit("Unlimited PDF reports", symbol: "doc.richtext.fill")
                        benefit("Excel, Word, and JPG exports", symbol: "square.and.arrow.up.fill")
                        benefit("Reusable merchant filing rules", symbol: "wand.and.stars")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                if await purchases.purchase() { dismiss() }
                                else { message = purchases.errorMessage }
                            }
                        } label: {
                            HStack {
                                if purchases.isLoading { ProgressView().tint(.white) }
                                Text(purchaseButtonTitle)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.teal)
                        .disabled(purchases.isLoading)

                        Text("One-time purchase. No subscription.")
                            .font(.footnote.bold())
                        Text("Payment is charged to your Apple Account. Purchases can be restored on devices using the same account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Restore Purchases") {
                            Task {
                                if await purchases.restore() { dismiss() }
                                else { message = purchases.errorMessage }
                            }
                        }
                        .disabled(purchases.isLoading)

                        HStack(spacing: 18) {
                            Link("Privacy Policy", destination: Self.privacyPolicyURL)
                            Link("Terms of Use", destination: Self.termsOfUseURL)
                        }
                        .font(.footnote)
                    }
                }
                .padding(24)
            }
            .navigationTitle("ReceiptSure Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .alert("ReceiptSure Pro", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "Please try again.")
            }
        }
    }

    private static let privacyPolicyURL = URL(string: "https://receipt-tracking-app-lemon.vercel.app/privacy")!
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private var purchaseButtonTitle: String {
        if let price = purchases.product?.displayPrice {
            return "Unlock Pro for \(price)"
        }
        return purchases.hasLoadedStore ? "Try loading price again" : "Loading App Store price…"
    }

    private func benefit(_ title: String, symbol: String) -> some View {
        Label {
            Text(title).font(.body.weight(.medium))
        } icon: {
            Image(systemName: symbol).foregroundStyle(.teal)
        }
    }
}
