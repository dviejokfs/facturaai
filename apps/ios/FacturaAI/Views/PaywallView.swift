import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var auth: AuthService

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

                    Text("Your trial has ended")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Keep the quarterly ZIP your accountant already loves.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Pro").font(.title).fontWeight(.bold).foregroundStyle(.indigo)
                            Spacer()
                            Text("€9,99/mo")
                                .font(.title3).fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                        }
                        Text("or €79/year — save 34%")
                            .font(.caption).foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        feature("Unlimited AI receipt scanning")
                        feature("Gmail auto-import")
                        feature("Multi-currency (EUR, USD, GBP, …)")
                        feature("Quarterly ZIP for your accountant")
                        feature("Excel + CSV + original invoices")

                        Button {
                            // TODO: StoreKit 2 purchase
                        } label: {
                            Text("Subscribe to Pro")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.indigo)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 6)
                    }
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)

                    Button {
                        auth.signOut()
                    } label: {
                        Text("Sign out")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
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
