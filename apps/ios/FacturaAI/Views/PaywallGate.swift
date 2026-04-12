import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// RevenueCat dashboard offering identifier to render on the paywall sheet.
/// Must match an offering in app.revenuecat.com → Offerings.
private let PAYWALL_OFFERING_ID = "invoscanai"

/// Lock state used by the paywall gate modifier.
enum PaywallEntitlement: String {
    case pro
    case business
}

/// Where in the app the paywall was triggered from. Used by RevenueCat targeting
/// rules to show different paywall variants per surface area.
///
/// Map these to RevenueCat **offerings** in the dashboard:
///   onboarding   → "default"
///   featureGate  → "default" (with `presented_offering_context` for the feature)
///   freeLimit    → "default"
///   trialExpired → "default"
///   manage       → "default" (or a separate offering if you want)
enum PaywallPlacement: String {
    case onboarding
    case featureGate = "feature_gate"
    case freeLimit = "free_limit"
    case trialExpired = "trial_expired"
    case manage
}

/// Wraps a view in a "this is locked" overlay until the user has the required
/// entitlement. Tapping the overlay opens the RevenueCat paywall.
///
/// Usage:
///   RecurringInvoicesView()
///       .paywallGate(.pro, feature: "recurring_invoices")
struct PaywallGateModifier: ViewModifier {
    @ObservedObject private var rc = RevenueCatService.shared
    @State private var showPaywall = false

    let entitlement: PaywallEntitlement
    let feature: String

    func body(content: Content) -> some View {
        let unlocked = rc.activeEntitlements.contains(entitlement.rawValue) ||
                       (entitlement == .pro && rc.activeEntitlements.contains("business"))

        ZStack {
            content
                .disabled(!unlocked)
                .blur(radius: unlocked ? 0 : 6)

            if !unlocked {
                LockedOverlay(feature: feature) {
                    showPaywall = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(placement: .featureGate)
        }
    }
}

extension View {
    /// Gate this view behind a RevenueCat entitlement. Shows a lock overlay if the
    /// user doesn't have the entitlement; opens a paywall when tapped.
    func paywallGate(_ entitlement: PaywallEntitlement, feature: String) -> some View {
        modifier(PaywallGateModifier(entitlement: entitlement, feature: feature))
    }
}

private struct LockedOverlay: View {
    let feature: String
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.indigo)
            Text(NSLocalizedString("paywall.gate.title", comment: ""))
                .font(.headline)
            Text(feature.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onTap) {
                Text(NSLocalizedString("paywall.gate.cta", comment: ""))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(28)
    }
}

/// The actual paywall sheet. Uses RevenueCatUI's remote-configured paywall when
/// the SDK is installed; falls back to a hand-rolled placeholder otherwise so the
/// app still builds and runs before you've added the RevenueCat package.
struct PaywallSheet: View {
    let placement: PaywallPlacement
    @Environment(\.dismiss) private var dismiss

    #if canImport(RevenueCat)
    @State private var offering: Offering?
    @State private var loadError: Error?
    #endif

    var body: some View {
        #if canImport(RevenueCatUI)
        VStack(spacing: 0) {
            Group {
                if let offering {
                    // Pin the paywall to our named offering so the dashboard change
                    // doesn't accidentally swap the current offering under our feet.
                    RevenueCatUI.PaywallView(offering: offering, displayCloseButton: true)
                        .onPurchaseCompleted { _ in
                            Task { await RevenueCatService.shared.refresh() }
                            dismiss()
                        }
                        .onRestoreCompleted { _ in
                            Task { await RevenueCatService.shared.refresh() }
                            dismiss()
                        }
                } else if loadError != nil {
                    // If the named offering is missing in the dashboard, fall back to
                    // the project's current offering rather than showing a blank sheet.
                    RevenueCatUI.PaywallView(displayCloseButton: true)
                        .onPurchaseCompleted { _ in
                            Task { await RevenueCatService.shared.refresh() }
                            dismiss()
                        }
                        .onRestoreCompleted { _ in
                            Task { await RevenueCatService.shared.refresh() }
                            dismiss()
                        }
                } else {
                    ProgressView().controlSize(.large)
                }
            }

            // Safety net: ensure the auto-renewal disclosure + legal links are
            // always visible under the paywall, regardless of dashboard config.
            LegalLinks()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
        }
        .task {
            do {
                let offerings = try await Purchases.shared.offerings()
                if let target = offerings.offering(identifier: PAYWALL_OFFERING_ID) {
                    self.offering = target
                } else {
                    self.loadError = NSError(
                        domain: "InvoScanAI.Paywall",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Offering '\(PAYWALL_OFFERING_ID)' not found"],
                    )
                }
            } catch {
                self.loadError = error
            }
        }
        #else
        FallbackPaywall(placement: placement) { dismiss() }
        #endif
    }
}

/// Pre-RevenueCat-install fallback so the app still has *something* to show in
/// the simulator before you wire up the SDK. Once you add the RevenueCat package
/// in Xcode, this code path is dead.
private struct FallbackPaywall: View {
    let placement: PaywallPlacement
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text(NSLocalizedString("paywall.fallback.title", comment: ""))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Add the RevenueCat Swift package and set RC_PUBLIC_SDK_KEY_IOS in Info.plist to enable purchases. Triggered placement: \(placement.rawValue)")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 32)
                Spacer()

                // Auto-renewal disclosure + legal links (required by Apple)
                LegalLinks(onDarkBackground: true)
                    .padding(.horizontal, 32)

                Button(action: onClose) {
                    Text(NSLocalizedString("common.close", comment: ""))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.white)
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 40)
            }
        }
    }
}
