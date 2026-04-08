import SwiftUI

@main
struct FacturaAIApp: App {
    @StateObject private var expenseStore = ExpenseStore()
    @StateObject private var authService = AuthService()
    @StateObject private var revenueCat = RevenueCatService.shared

    init() {
        RevenueCatService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(expenseStore)
                .environmentObject(authService)
                .environmentObject(revenueCat)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    guard url.scheme == "facturaai", url.host == "share" else { return }
                    Task { await SharedInboxService.shared.ingest(from: url, store: expenseStore) }
                }
        }
    }
}
