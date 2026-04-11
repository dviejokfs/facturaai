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
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab: Int = 0
    @State private var showScan = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(onScanTap: { showScan = true })
                    .tabItem { Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill") }
                    .tag(0)
                ExpensesListView(onScanTap: { showScan = true })
                    .tabItem { Label(NSLocalizedString("tab.invoices", comment: ""), systemImage: "doc.text.fill") }
                    .tag(1)
                ExportView()
                    .tabItem { Label(NSLocalizedString("tab.export", comment: ""), systemImage: "square.and.arrow.up") }
                    .tag(2)
                SettingsView()
                    .tabItem { Label(NSLocalizedString("tab.settings", comment: ""), systemImage: "gearshape.fill") }
                    .tag(3)
            }
            .tint(.indigo)

            // Floating scan button
            Button {
                showScan = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: .indigo.opacity(0.4), radius: 8, y: 4)
            }
            .accessibilityLabel(NSLocalizedString("a11y.scan_button", comment: ""))
            .offset(y: -28)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { notif in
            if let tab = notif.object as? Int {
                selectedTab = tab
            }
        }
        .fullScreenCover(isPresented: $showScan) {
            NavigationStack {
                ScanView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(NSLocalizedString("common.close", comment: "")) {
                                showScan = false
                            }
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToExpense)) { _ in
            // Dismiss scan cover if open so the invoice detail can be shown
            showScan = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .upgradeNeeded)) { notif in
            if let reason = notif.object as? UpgradeReason {
                auth.handleUpgradeNeeded(reason)
            }
        }
        .sheet(isPresented: $auth.showUpgradePaywall) {
            UpgradePaywallSheet(reason: auth.upgradeReason)
        }
    }
}

/// Sheet presented when the backend returns 403 with `upgrade: true`.
/// Shows a contextual title/message based on the reason, then the standard paywall.
private struct UpgradePaywallSheet: View {
    let reason: UpgradeReason
    @Environment(\.dismiss) private var dismiss

    var title: String {
        switch reason {
        case .limitReached: return NSLocalizedString("paywall.limit_reached.title", comment: "")
        case .trialExpired: return NSLocalizedString("paywall.trial_expired.title", comment: "")
        case .unknown: return NSLocalizedString("paywall.limit_reached.title", comment: "")
        }
    }

    var message: String {
        switch reason {
        case .limitReached: return NSLocalizedString("paywall.limit_reached.message", comment: "")
        case .trialExpired: return NSLocalizedString("paywall.trial_expired.message", comment: "")
        case .unknown: return NSLocalizedString("paywall.limit_reached.message", comment: "")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: reason == .trialExpired ? "clock.badge.exclamationmark" : "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(title)
                        .font(.title2.bold())
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                PaywallSheet(placement: reason == .trialExpired ? .trialExpired : .freeLimit)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", comment: "")) { dismiss() }
                }
            }
        }
    }
}
