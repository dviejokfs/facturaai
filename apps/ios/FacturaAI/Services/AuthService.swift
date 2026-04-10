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
    @Published var accountantName: String?
    @Published var accountantEmail: String?
    @Published var taxId: String?
    @Published var googleTokenExpiry: Date?
    @Published var googleHasRefreshToken: Bool = false
    @Published var companyName: String?

    /// Set to `true` when any API call returns 403 with `upgrade: true`.
    /// MainTabView observes this and presents a PaywallSheet.
    @Published var showUpgradePaywall: Bool = false
    /// The reason the upgrade paywall was triggered (limit_reached, trial_expired, etc.).
    @Published var upgradeReason: UpgradeReason = .unknown

    /// Call from any catch block that receives an `APIError.upgradeNeeded`.
    func handleUpgradeNeeded(_ reason: UpgradeReason) {
        upgradeReason = reason
        showUpgradePaywall = true
    }

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
        let scheme = "invoscanai"

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
                errorMessage = "No token in callback"
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
            self.accountantName = me.accountantName
            self.accountantEmail = me.accountantEmail
            self.taxId = me.taxId
            self.gmailConnected = me.gmailConnected ?? false
            self.googleTokenExpiry = me.googleTokenExpiry
            self.googleHasRefreshToken = me.googleHasRefreshToken ?? false
            self.companyName = me.companyName
            await RevenueCatService.shared.identify(userId: me.id, email: me.email)
        } catch {
            print("refreshProfile failed: \(error)")
            if case APIError.http(401, _) = error {
                print("401 → signing out")
                signOut()
            }
            // Don't sign out for non-401 errors (network issues, etc.)
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        errorMessage = nil
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Failed to get Apple identity token"
            return
        }

        let email = credential.email
        var fullName: [String: String?]? = nil
        if let name = credential.fullName {
            fullName = [
                "givenName": name.givenName,
                "familyName": name.familyName,
            ]
        }

        do {
            let body: [String: Any?] = [
                "identityToken": identityToken,
                "email": email as Any,
                "fullName": fullName as Any,
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
            let url = APIClient.shared.baseURL.appendingPathComponent("auth/apple/callback")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                errorMessage = "Sign in failed: \(body)"
                return
            }

            let result = try JSONDecoder().decode(AppleSignInResponse.self, from: data)
            Keychain.saveToken(result.token)
            isSignedIn = true
            await refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        Task { await RevenueCatService.shared.signOut() }
        Keychain.deleteToken()
        isSignedIn = false
        userEmail = nil
        gmailConnected = false
        googleTokenExpiry = nil
        googleHasRefreshToken = false
        plan = "trial"
        trialDaysLeft = 0
        trialExpired = false
        accountantName = nil
        accountantEmail = nil
        taxId = nil
        companyName = nil
        errorMessage = nil
        onSignOut?()
    }

    /// Called after sign-out to let the app clear related stores (e.g. ExpenseStore).
    var onSignOut: (() -> Void)?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private struct AppleSignInResponse: Decodable {
    let token: String
}
