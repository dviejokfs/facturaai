import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userEmail: String?
    @Published var gmailConnected: Bool = false

    func signInWithGoogle() async {
        // Stub: in production, integrate GoogleSignIn SDK + request Gmail read-only scope.
        try? await Task.sleep(nanoseconds: 800_000_000)
        self.userEmail = "maria@ejemplo.es"
        self.isSignedIn = true
        self.gmailConnected = true
    }

    func signOut() {
        isSignedIn = false
        userEmail = nil
        gmailConnected = false
    }
}
