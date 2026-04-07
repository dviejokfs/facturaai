import Foundation
import AuthenticationServices
import UIKit

@MainActor
final class AuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var isSignedIn: Bool = false
    @Published var userEmail: String?
    @Published var gmailConnected: Bool = false
    @Published var plan: String = "trial"
    @Published var trialDaysLeft: Int = 14
    @Published var trialExpired: Bool = false
    @Published var errorMessage: String?

    override init() {
        super.init()
        if Keychain.loadToken() != nil {
            self.isSignedIn = true
            Task { await refreshProfile() }
        }
    }

    func signInWithGoogle() async {
        errorMessage = nil
        let authURL = APIClient.shared.startGoogleAuthURL()
        let scheme = "facturaai"

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
                let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { url, error in
                    if let url { cont.resume(returning: url) }
                    else { cont.resume(throwing: error ?? NSError(domain: "auth", code: -1)) }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }

            guard let token = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "token" })?.value else {
                errorMessage = "No token en el callback"
                return
            }

            Keychain.saveToken(token)
            isSignedIn = true
            gmailConnected = true
            await refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshProfile() async {
        do {
            let me = try await APIClient.shared.meProfile()
            self.userEmail = me.email
            self.plan = me.plan
            self.trialDaysLeft = me.trialDaysLeft ?? 0
            self.trialExpired = me.trialExpired ?? false
        } catch {
            if case APIError.http(401, _) = error {
                signOut()
            }
        }
    }

    func signOut() {
        Keychain.deleteToken()
        isSignedIn = false
        userEmail = nil
        gmailConnected = false
        plan = "trial"
        trialDaysLeft = 0
        trialExpired = false
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
