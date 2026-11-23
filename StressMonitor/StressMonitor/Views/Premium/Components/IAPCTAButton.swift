import SwiftUI

struct IAPCTAButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            action()
        }) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(Typography.iapCTA)
                            .tracking(-0.02 * 16)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.iapCTATeal, Color.iapHeaderTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.iapHeaderTeal.opacity(0.26), radius: 14, y: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 24) {
        IAPCTAButton(title: "Start 14-day free trial", isLoading: false, action: {})
        IAPCTAButton(title: "Subscribe", isLoading: false, action: {})
        IAPCTAButton(title: "Subscribe", isLoading: true, action: {})
    }
    .padding(.horizontal, 17)
    .background(Color.Wellness.adaptiveBackground)
}
