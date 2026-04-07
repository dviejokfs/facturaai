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

                    Image(systemName: "hourglass")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)

                    Text("Tu prueba ha terminado")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Elige un plan para seguir automatizando tus facturas.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        PaywallPlanCard(
                            name: "Pro",
                            price: "€6,99/mes",
                            annual: "o €59/año",
                            badge: "Más popular"
                        )
                        PaywallPlanCard(
                            name: "Business",
                            price: "€12,99/mes",
                            annual: "o €109/año",
                            badge: nil
                        )
                    }
                    .padding(.horizontal, 20)

                    Button {
                        auth.signOut()
                    } label: {
                        Text("Cerrar sesión")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

private struct PaywallPlanCard: View {
    let name: String
    let price: String
    let annual: String
    let badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name).font(.title2).fontWeight(.bold).foregroundStyle(.indigo)
                Spacer()
                if let badge {
                    Text(badge).font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.yellow)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }
            Text(price).font(.title3).fontWeight(.semibold)
            Text(annual).font(.caption).foregroundStyle(.secondary)
            Button {
                // TODO: StoreKit
            } label: {
                Text("Suscribirme a \(name)")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
