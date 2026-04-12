import SwiftUI

/// Auto-renewal disclosure + tappable Terms / Privacy links, required by
/// App Store Review Guideline 3.1.2 to appear in proximity to the subscribe
/// button (not only in the marketing screen).
struct LegalLinks: View {
    /// Tints the labels against dark backgrounds when true.
    var onDarkBackground: Bool = false

    private var primaryColor: Color {
        onDarkBackground ? .white.opacity(0.95) : .primary
    }
    private var mutedColor: Color {
        onDarkBackground ? .white.opacity(0.7) : .secondary
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(NSLocalizedString("paywall.disclosure", comment: ""))
                .font(.caption2)
                .foregroundStyle(mutedColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text(NSLocalizedString("paywall.legal.agree", comment: ""))
                    .foregroundStyle(mutedColor)
                Link(destination: URL(string: "https://invoscan.ai/terms")!) {
                    Text(NSLocalizedString("paywall.legal.terms", comment: ""))
                        .underline()
                        .foregroundStyle(primaryColor)
                }
                Text(NSLocalizedString("paywall.legal.and", comment: ""))
                    .foregroundStyle(mutedColor)
                Link(destination: URL(string: "https://invoscan.ai/privacy")!) {
                    Text(NSLocalizedString("paywall.legal.privacy", comment: ""))
                        .underline()
                        .foregroundStyle(primaryColor)
                }
            }
            .font(.caption2)
        }
        .frame(maxWidth: .infinity)
    }
}
