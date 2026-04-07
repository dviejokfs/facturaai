import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        if !auth.isSignedIn {
            OnboardingView()
        } else if auth.trialExpired && auth.plan == "trial" {
            PaywallView()
        } else {
            MainTabView()
                .task { await store.reload() }
        }
    }

    @EnvironmentObject var store: ExpenseStore
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Resumen", systemImage: "chart.pie.fill") }
            ExpensesListView()
                .tabItem { Label("Gastos", systemImage: "list.bullet.rectangle") }
            ScanView()
                .tabItem { Label("Escanear", systemImage: "camera.fill") }
            ExportView()
                .tabItem { Label("Exportar", systemImage: "square.and.arrow.up") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
        .tint(.indigo)
    }
}
