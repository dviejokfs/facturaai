import SwiftUI
import AuthenticationServices

struct SignInPrompt: View {
    @EnvironmentObject var auth: AuthService
    let title: String
    let subtitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 64))
                        .foregroundStyle(.indigo)

                    Text(title)
                        .font(.title2).fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 12) {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.email, .fullName]
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    Task {
                                        loading = true
                                        await auth.signInWithApple(credential: credential)
                                        loading = false
                                        if auth.isSignedIn { dismiss() }
                                    }
                                }
                            case .failure(let error):
                                let nsError = error as NSError
                                print("Apple Sign In failed: domain=\(nsError.domain) code=\(nsError.code) desc=\(nsError.localizedDescription)")
                                if nsError.code != ASAuthorizationError.canceled.rawValue {
                                    auth.errorMessage = "Apple Sign In error (\(nsError.code)): \(nsError.localizedDescription)"
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(loading)

                        // Sign in with Google
                        Button {
                            Task {
                                loading = true
                                await auth.signInWithGoogle()
                                loading = false
                                if auth.isSignedIn { dismiss() }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text(NSLocalizedString("signIn.google", comment: "")).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(loading)
                    }
                    .padding(.horizontal, 24)

                    if let err = auth.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)
                    }

                    Text(NSLocalizedString("signIn.trial_hint", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .opacity(loading ? 0.4 : 1)

                // Blocking spinner
                if loading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.indigo)
                        Text(NSLocalizedString("signIn.signing_in", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                        .disabled(loading)
                }
            }
            .onAppear { auth.errorMessage = nil }
        }
    }
}
