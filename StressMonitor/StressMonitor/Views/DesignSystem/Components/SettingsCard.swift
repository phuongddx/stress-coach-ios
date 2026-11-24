import SwiftUI

/// Padded card container for the Settings screen (UI V2): a `V2Card` with
/// `surface`, radius 22, hairline border and a soft shadow in light mode.
struct SettingsCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = V2Metrics.margin

    init(padding: CGFloat = V2Metrics.margin, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        V2Card(padding: padding) {
            content
        }
    }
}

struct SettingsCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SettingsCard {
                Text("Settings Card Content")
                    .foregroundStyle(Color.V2.ink)
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Title")
                        .font(.headline)
                        .foregroundStyle(Color.V2.ink)
                    Text("Card description text goes here")
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink3)
                }
            }
        }
        .padding()
        .background(Color.V2.bg)
    }
}
