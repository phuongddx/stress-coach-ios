import SwiftUI

/// About screen: app identity (version, build), legal links, acknowledgements,
/// and contact. Reads the version from the main bundle so it stays accurate
/// across TestFlight and App Store builds.
struct AboutView: View {
    @State private var docsURL: URL? = nil

    @ScaledMetric(relativeTo: .largeTitle) private var tileSize: CGFloat = 88

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                identitySection
                legalSection
                acknowledgementsSection
                contactSection
                Text("Made for calmer days. Not a medical device.")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
        .sheet(item: $docsURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: V2Metrics.radiusLG, style: .continuous)
                    .fill(Color.V2.accentSoft)
                StressBuddyIllustration(mood: .happy, size: tileSize * 0.66, pose: .base)
            }
            .frame(width: tileSize, height: tileSize)
            .accessibilityHidden(true)

            Text("StressMonitor")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.V2.ink)

            Text("Version \(versionText) (\(buildText))")
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink3)
                .monospacedDigit()

            Text("Designed for iOS 18.6 and watchOS 11.6. Stress is calculated on your device. Health summaries leave it only if you turn on Health Data Sync, and AI coaching sends derived stress scores, not raw Health readings.")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Legal")
            ActionGroupCard {
                VStack(spacing: 0) {
                    linkRow(icon: "hand.raised.fill", title: "Privacy Policy") { docsURL = DocsURL.privacy }
                    ActionRowDivider()
                    linkRow(icon: "doc.text.fill", title: "Terms of Service") { docsURL = DocsURL.terms }
                }
            }
        }
    }

    // MARK: - Acknowledgements

    private var acknowledgementsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Acknowledgements")
            ActionGroupCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built with Apple HealthKit, SwiftData, and CloudKit.")
                    Text("No third-party analytics or ad SDKs.")
                }
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(V2Metrics.margin)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Contact")
            ActionGroupCard {
                VStack(spacing: 0) {
                    if let email = URL(string: "mailto:support@stressmonitor.app") {
                        Link(destination: email) {
                            SettingsRowLabel(icon: "envelope.fill", title: "support@stressmonitor.app") {
                                externalMark
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Email support")
                        ActionRowDivider()
                    }
                    linkRow(icon: "questionmark.circle.fill", title: "Help & FAQ") { docsURL = DocsURL.help }
                }
            }
        }
    }

    // MARK: - Helpers

    private func linkRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsRowLabel(icon: icon, title: title) {
                externalMark
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Opens in Safari")
    }

    /// External-link accessory: these rows open Safari or Mail.
    private var externalMark: some View {
        Image(systemName: "arrow.up.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.V2.ink3)
            .accessibilityHidden(true)
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
