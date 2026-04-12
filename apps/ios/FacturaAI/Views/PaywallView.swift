import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var auth: AuthService
    @ObservedObject private var rc = RevenueCatService.shared
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showPaywallSheet = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 40)

                    Image(systemName: "sparkles")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)

                    Text(NSLocalizedString("paywall.title", comment: ""))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("paywall.subtitle", comment: ""))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(NSLocalizedString("paywall.pro", comment: "")).font(.title).fontWeight(.bold).foregroundStyle(.indigo)
                            Spacer()
                            Text(NSLocalizedString("paywall.price.monthly", comment: ""))
                                .font(.title3).fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                        }
                        Text(NSLocalizedString("paywall.price.yearly", comment: ""))
                            .font(.caption).foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        feature(NSLocalizedString("paywall.feature.scanning", comment: ""))
                        feature(NSLocalizedString("paywall.feature.gmail", comment: ""))
                        feature(NSLocalizedString("paywall.feature.currency", comment: ""))
                        feature(NSLocalizedString("paywall.feature.zip", comment: ""))
                        feature(NSLocalizedString("paywall.feature.export", comment: ""))

                        Button {
                            showPaywallSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(NSLocalizedString("paywall.subscribe", comment: ""))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.indigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isPurchasing)
                        .padding(.top, 6)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        // Auto-renewal disclosure + tappable legal links (required by Apple)
                        LegalLinks()
                            .padding(.top, 4)
                    }
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)

                    Button {
                        Task {
                            isPurchasing = true
                            let restored = await rc.restorePurchases()
                            isPurchasing = false
                            if !restored {
                                errorMessage = NSLocalizedString("paywall.restore.nothing", comment: "")
                            }
                        }
                    } label: {
                        Text(NSLocalizedString("settings.restorePurchases", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .disabled(isPurchasing)

                    Button {
                        auth.signOut()
                    } label: {
                        Text(NSLocalizedString("settings.signOut", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showPaywallSheet) {
            PaywallSheet(placement: .trialExpired)
        }
    }

    @ViewBuilder
    private func feature(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}
