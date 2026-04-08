import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ExpenseStore
    @AppStorage("hasCompletedFirstUse") private var hasCompletedFirstUse = false

    private var screenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestScreenshotMode")
    }

    var body: some View {
        if screenshotMode {
            MainTabView()
        } else if !hasCompletedFirstUse {
            FirstUseView()
        } else {
            MainTabView()
                .task {
                    if auth.isSignedIn {
                        await store.reload()
                    }
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "chart.pie.fill") }
            ExpensesListView()
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle") }
            ScanView()
                .tabItem { Label("Scan", systemImage: "camera.fill") }
            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.indigo)
    }
}
