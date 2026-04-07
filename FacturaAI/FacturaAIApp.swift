import SwiftUI

@main
struct FacturaAIApp: App {
    @StateObject private var expenseStore = ExpenseStore()
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(expenseStore)
                .environmentObject(authService)
                .preferredColorScheme(.light)
        }
    }
}
