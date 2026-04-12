import SwiftUI
import UserNotifications

@main
struct InvoScanAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var expenseStore = ExpenseStore()
    @StateObject private var authService = AuthService()
    @StateObject private var revenueCat = RevenueCatService.shared

    init() {
        RevenueCatService.shared.configure()
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(expenseStore)
                .environmentObject(authService)
                .environmentObject(revenueCat)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    if url.scheme == "invoscanai", url.host == "share" {
                        Task { await SharedInboxService.shared.ingest(from: url, store: expenseStore) }
                    } else if url.isFileURL {
                        Task { await SharedInboxService.shared.ingestFile(at: url, store: expenseStore) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .shouldRequestPushPermission)) { _ in
                    requestPushNotifications()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await expenseStore.checkActiveSync() }
                    }
                }
                .alert(
                    NSLocalizedString("notifications.permission.title", comment: ""),
                    isPresented: $showNotificationDialog
                ) {
                    Button(NSLocalizedString("notifications.permission.enable", comment: "")) {
                        performNotificationRequest()
                    }
                    Button(NSLocalizedString("notifications.permission.later", comment: ""), role: .cancel) {}
                } message: {
                    Text(NSLocalizedString("notifications.permission.message", comment: ""))
                }
        }
    }

    @AppStorage("hasRequestedNotifications") private var hasRequestedNotifications = false
    @State private var showNotificationDialog = false

    private func requestPushNotifications() {
        guard !hasRequestedNotifications else { return }
        showNotificationDialog = true
    }

    private func performNotificationRequest() {
        hasRequestedNotifications = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String

        DispatchQueue.main.async {
            switch type {
            case "gmail_sync", "new_invoices":
                NotificationCenter.default.post(name: .switchToTab, object: 1) // Invoices tab
            case "export_ready":
                NotificationCenter.default.post(name: .switchToTab, object: 2) // Export tab
            default:
                NotificationCenter.default.post(name: .switchToTab, object: 0) // Dashboard
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard Keychain.loadToken() != nil else { return }
        Task {
            do {
                try await APIClient.shared.registerDevice(token: token)
            } catch {
                print("[AppDelegate] Failed to register device token: \(error)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[AppDelegate] Push registration failed: \(error)")
    }
}
