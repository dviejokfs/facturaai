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
                        // TODO: handle Apple sign-in
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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
                            if loading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "g.circle.fill")
                                Text("Sign in with Google").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                if let err = auth.errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                Text("14-day free trial. No credit card required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
