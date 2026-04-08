import Foundation
import Combine

#if canImport(RevenueCat)
import RevenueCat
#endif

/// Thin wrapper around RevenueCat's `Purchases` SDK.
///
/// All gating in the app goes through this service so that:
///   1. The rest of the app never imports RevenueCat directly — easy to mock for tests
///      and easy to swap providers later if we ever need to.
///   2. We can run the app in DEBUG without the RevenueCat SDK installed yet (the
///      `#if canImport(RevenueCat)` blocks no-op gracefully on a fresh checkout).
///
/// SETUP CHECKLIST (do these once, in this order):
///
///   1. Add the RevenueCat + RevenueCatUI Swift packages to the Xcode project:
///      File → Add Package Dependencies → https://github.com/RevenueCat/purchases-ios
///      Add both `RevenueCat` and `RevenueCatUI` library products.
///
///   2. In the FacturaAI target → Signing & Capabilities, add the **In-App Purchase**
///      capability.
///
///   3. In the FacturaAI scheme → Run → Options, set "StoreKit Configuration" to
///      `FacturaAI/Configuration.storekit` so the simulator runs against local
///      sandbox products instead of needing App Store Connect.
///
///   4. Sign up at https://app.revenuecat.com, create the FacturaAI project, create
///      the four products (matching `Configuration.storekit` IDs), create the
///      `pro` and `business` entitlements, create the `default` offering, and copy
///      the public iOS SDK key.
///
///   5. Paste the SDK key into `Info.plist` under `RC_PUBLIC_SDK_KEY_IOS` (or set
///      `Self.publicSDKKey` below directly while testing).
///
///   6. Configure the webhook in RevenueCat → Project Settings → Integrations →
///      Webhooks pointing at `https://<your-host>/webhooks/revenuecat` with the
///      Authorization header `Bearer <REVENUECAT_WEBHOOK_SECRET>`.
@MainActor
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    /// Active entitlement identifiers, refreshed whenever `CustomerInfo` changes.
    @Published private(set) var activeEntitlements: Set<String> = []

    /// Convenience flags used by the rest of the UI.
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isBusiness: Bool = false
    @Published private(set) var isInTrial: Bool = false
    @Published private(set) var willRenew: Bool = true
    @Published private(set) var expiresAt: Date?

    /// True once `configure()` has been called and the SDK is ready.
    @Published private(set) var isConfigured: Bool = false

    private init() {}

    // MARK: - Configuration

    /// Read the SDK key from Info.plist; falls back to the empty string so the
    /// app still launches in development before you've signed up to RevenueCat.
    private static var publicSDKKey: String {
        Bundle.main.object(forInfoDictionaryKey: "RC_PUBLIC_SDK_KEY_IOS") as? String ?? ""
    }

    /// Call once at app launch (from `FacturaAIApp.init`).
    func configure() {
        #if canImport(RevenueCat)
        guard !Self.publicSDKKey.isEmpty else {
            print("[RevenueCat] Skipping configure(): RC_PUBLIC_SDK_KEY_IOS not set in Info.plist. " +
                  "Sign up at revenuecat.com and add it to enable purchases.")
            return
        }
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: Self.publicSDKKey)
        Purchases.shared.delegate = RCDelegate.shared
        isConfigured = true
        Task { await refresh() }
        #else
        print("[RevenueCat] SDK not yet installed — add the package in Xcode to enable.")
        #endif
    }

    /// Identify the current user to RevenueCat. Call this immediately after sign-in,
    /// passing your backend's user UUID. The webhook handler relies on this so it
    /// can resolve `app_user_id` back to a row in our `users` table.
    func identify(userId: String, email: String?) async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            _ = try await Purchases.shared.logIn(userId)
            if let email {
                Purchases.shared.attribution.setEmail(email)
            }
            await refresh()
        } catch {
            print("[RevenueCat] logIn failed: \(error)")
        }
        #endif
    }

    /// Pass user metadata to RevenueCat so the dashboard can build targeting rules
    /// without us needing to ship app updates. Safe to call multiple times.
    func setAttributes(countryCode: String?, primaryCurrency: String?, userType: String?) {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        var attrs: [String: String] = [:]
        if let countryCode { attrs["country_code"] = countryCode }
        if let primaryCurrency { attrs["primary_currency"] = primaryCurrency }
        if let userType { attrs["user_type"] = userType }
        if !attrs.isEmpty {
            Purchases.shared.attribution.setAttributes(attrs)
        }
        #endif
    }

    /// Sign out of RevenueCat (resets to an anonymous app user id).
    func signOut() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            _ = try await Purchases.shared.logOut()
            await refresh()
        } catch {
            print("[RevenueCat] logOut failed: \(error)")
        }
        #endif
    }

    /// Pull the latest CustomerInfo from RevenueCat and update published state.
    func refresh() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            print("[RevenueCat] customerInfo failed: \(error)")
        }
        #endif
    }

    /// Restore purchases (required by App Store guidelines on every paywall).
    func restorePurchases() async -> Bool {
        #if canImport(RevenueCat)
        guard isConfigured else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return !activeEntitlements.isEmpty
        } catch {
            print("[RevenueCat] restorePurchases failed: \(error)")
            return false
        }
        #else
        return false
        #endif
    }

    #if canImport(RevenueCat)
    fileprivate func apply(_ info: CustomerInfo) {
        let active = Set(info.entitlements.active.keys)
        self.activeEntitlements = active
        self.isPro = active.contains("pro") || active.contains("business")
        self.isBusiness = active.contains("business")
        let proOrBusiness = info.entitlements["business"] ?? info.entitlements["pro"]
        self.isInTrial = proOrBusiness?.periodType == .trial
        self.willRenew = proOrBusiness?.willRenew ?? false
        self.expiresAt = proOrBusiness?.expirationDate
    }
    #endif
}

#if canImport(RevenueCat)
/// Bridge RevenueCat's delegate (which is not @MainActor) into our @MainActor service.
private final class RCDelegate: NSObject, PurchasesDelegate {
    static let shared = RCDelegate()

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            RevenueCatService.shared.apply(customerInfo)
        }
    }
}
#endif
