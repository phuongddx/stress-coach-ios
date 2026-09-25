import SwiftUI

/// About screen: app identity (version, build), legal links, acknowledgements,
/// and contact. Reads the version from the main bundle so it stays accurate
/// across TestFlight and App Store builds.
struct AboutView: View {
    @State private var docsURL: URL? = nil

    var body: some View {
        Form {
            identitySection
            legalSection
            acknowledgementsSection
            contactSection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
        .sheet(item: $docsURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        Section {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HomeCharacterDesignTokens.Ripple.primary.opacity(0.18))
                        .frame(width: 80, height: 80)
                    StressBuddyIllustration(mood: .happy, size: 56)
                }
                .accessibilityHidden(true)

                Text("StressMonitor")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                Text("\(versionText) (\(buildText))")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        } footer: {
            Text("Designed for iOS 17 and watchOS 10. All health signals stay on device unless you enable iCloud sync.")
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section("Legal") {
            linkRow(icon: "hand.raised", title: "Privacy Policy") { docsURL = DocsURL.privacy }
            linkRow(icon: "doc.text", title: "Terms of Service") { docsURL = DocsURL.terms }
        }
    }

    // MARK: - Acknowledgements

    private var acknowledgementsSection: some View {
        Section("Acknowledgements") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Built with Apple HealthKit, SwiftData, and CloudKit.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                Text("No third-party analytics or ad SDKs.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        Section("Contact") {
            if let email = URL(string: "mailto:support@stressmonitor.app") {
                Link(destination: email) {
                    rowLabel(icon: "envelope", title: "support@stressmonitor.app")
                }
                .accessibilityLabel("Email support")
            }
            linkRow(icon: "questionmark.circle", title: "Help & FAQ") { docsURL = DocsURL.help }
        }
    }

    // MARK: - Helpers

    private func linkRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(icon: icon, title: title, showChevron: true)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(icon: String, title: String, showChevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 26)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Spacer()
            if showChevron {
                Image(systemName: AppIconSystem.Nav.forward.sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var versionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildText: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
