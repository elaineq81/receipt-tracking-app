import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        Form {
            Section("Your data") {
                Label("Stored on this device", systemImage: "iphone.and.arrow.forward")
                Text("Receipt images and extracted expense details stay in the app’s private local store. Nothing is uploaded by this version.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Capture & accuracy") {
                Label("Automatic edge detection and crop", systemImage: "viewfinder")
                Label("On-device Apple Vision OCR", systemImage: "text.viewfinder")
                Text("Always compare extracted totals with the original receipt before relying on a report for accounting or tax purposes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                NavigationLink("Privacy summary") { PrivacySummaryView() }
                Button("Show onboarding again") { hasCompletedOnboarding = false }
            }
        }
        .navigationTitle("Settings")
    }
}

private struct PrivacySummaryView: View {
    var body: some View {
        List {
            Section("Camera") { Text("Used only when you choose to scan a receipt. VisionKit detects the document boundary and crops the image.") }
            Section("Photos") { Text("The system photo picker can import only the images you select; the app does not request broad photo library access.") }
            Section("Sharing") { Text("Exports leave the app only when you choose a destination in Apple’s share sheet.") }
            Section("Collection") { Text("This version includes no accounts, analytics, advertising, tracking, or server upload.") }
        }
        .navigationTitle("Privacy")
    }
}

