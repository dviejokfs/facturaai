import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService
    @State private var loading = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo.opacity(0.9), .purple.opacity(0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)

                Text("FacturaAI")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Tu piloto automático fiscal.\nEncuentra todas tus facturas en Gmail automáticamente.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    FeatureRow(icon: "envelope.badge.fill", text: "Escaneo automático de Gmail")
                    FeatureRow(icon: "camera.viewfinder", text: "Escanea tickets con la cámara")
                    FeatureRow(icon: "doc.text.magnifyingglass", text: "Listo para tu gestoría")
                }
                .padding(.horizontal, 32)

                Spacer()

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
                            Image(systemName: "g.circle.fill")
                            Text("Continuar con Google").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundStyle(.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .disabled(loading)

                Text("Al continuar, aceptas los términos y la política de privacidad.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 24)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 32)
            Text(text)
                .foregroundStyle(.white)
            Spacer()
        }
    }
}
