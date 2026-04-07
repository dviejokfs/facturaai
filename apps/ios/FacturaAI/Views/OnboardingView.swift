import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService
    @State private var page = 0
    @State private var loading = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            TabView(selection: $page) {
                IntroPage(
                    icon: "sparkles.rectangle.stack.fill",
                    title: "FacturaAI",
                    subtitle: "Tu piloto automático fiscal.\nTodas tus facturas, organizadas por IA."
                ).tag(0)

                IntroPage(
                    icon: "envelope.badge.fill",
                    title: "Conecta Gmail",
                    subtitle: "Encontramos todas tus facturas automáticamente. Sin mover un dedo."
                ).tag(1)

                IntroPage(
                    icon: "camera.viewfinder",
                    title: "Escanea tickets",
                    subtitle: "Una foto y listo. La IA extrae base, IVA, categoría y más."
                ).tag(2)

                TrialPage(loading: $loading).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

private struct IntroPage: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 96))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

private struct TrialPage: View {
    @EnvironmentObject var auth: AuthService
    @Binding var loading: Bool

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "crown.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)

            Text("14 días gratis")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Acceso completo a Pro.\nSin tarjeta. Cancela cuando quieras.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                Bullet("Sincronización Gmail automática")
                Bullet("Escaneo IA de tickets ilimitado")
                Bullet("Export CSV + Excel + Email")
                Bullet("Categorización fiscal española completa")
                Bullet("Envío directo a tu gestoría")
            }
            .padding(20)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Task {
                        loading = true
                        await auth.signInWithGoogle()
                        loading = false
                    }
                } label: {
                    HStack {
                        if loading {
                            ProgressView().tint(.indigo)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Empezar prueba gratis").fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .foregroundStyle(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text("Luego €6,99/mes · Cancela cuando quieras")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 24)

            if let err = auth.errorMessage {
                Text(err).font(.caption).foregroundStyle(.orange).padding(.top, 4)
            }

            Text("Al continuar, aceptas los términos y la política de privacidad.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 28)
                .padding(.horizontal, 32)
                .multilineTextAlignment(.center)
        }
    }
}

private struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text).foregroundStyle(.white)
            Spacer()
        }
    }
}
