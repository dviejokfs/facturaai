import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ExpenseStore
    @StateObject private var localeService = LocaleService.shared
    @State private var showSignIn = false

    var planLabel: String {
        switch auth.plan {
        case "trial": return "Trial · \(auth.trialDaysLeft)d remaining"
        case "pro": return "Pro — €6.99/mo"
        case "business": return "Business — €12.99/mo"
        case "expired": return "Trial expired"
        default: return auth.plan
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !auth.isSignedIn {
                    Section {
                        Button {
                            showSignIn = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2)
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading) {
                                    Text("Sign in").fontWeight(.semibold)
                                    Text("Sync, export & manage your expenses")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if auth.isSignedIn, auth.plan == "trial", auth.trialDaysLeft <= 5 {
                    Section {
                        TrialBanner(daysLeft: auth.trialDaysLeft)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if auth.isSignedIn {
                    Section("Account") {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading) {
                                Text(auth.userEmail ?? "—").fontWeight(.semibold)
                                Text(planLabel).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if auth.isSignedIn {
                    Section(NSLocalizedString("settings.accountant", comment: "")) {
                        NavigationLink {
                            AccountantSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "person.text.rectangle.fill").foregroundStyle(.teal)
                                VStack(alignment: .leading) {
                                    Text(NSLocalizedString("accountant.title", comment: ""))
                                    if let email = auth.accountantEmail, !email.isEmpty {
                                        Text(email).font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text(NSLocalizedString("accountant.not_configured", comment: ""))
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }

                    Section("Integrations") {
                        HStack {
                            Image(systemName: "envelope.fill").foregroundStyle(.red)
                            Text("Gmail")
                            Spacer()
                            Text(auth.gmailConnected ? "Connected" : "Disconnected")
                                .font(.caption)
                                .foregroundStyle(auth.gmailConnected ? .green : .secondary)
                        }
                        HStack {
                            Image(systemName: "icloud.fill").foregroundStyle(.blue)
                            Text("Google Drive")
                            Spacer()
                            Text("Coming soon").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Image(systemName: "building.columns.fill").foregroundStyle(.teal)
                            Text("Bank (PSD2)")
                            Spacer()
                            Text("Coming soon").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Section("Plan") {
                        NavigationLink {
                            PricingView()
                        } label: {
                            Label(auth.plan == "pro" || auth.plan == "business"
                                  ? "Change plan"
                                  : "View Pro and Business plans",
                                  systemImage: "sparkles")
                        }
                        Button {
                            Task { _ = await RevenueCatService.shared.restorePurchases() }
                        } label: {
                            Label("Restore purchases", systemImage: "arrow.clockwise")
                        }
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            Label("Manage subscription", systemImage: "creditcard")
                        }
                    }
                }

                Section(NSLocalizedString("settings.language", comment: "")) {
                    Picker(NSLocalizedString("settings.language", comment: ""),
                           selection: Binding(
                            get: { localeService.override ?? "system" },
                            set: { newValue in
                                localeService.override = (newValue == "system") ? nil : newValue
                                if newValue != "system" {
                                    Task { try? await APIClient.shared.updateProfile(["locale": newValue]) }
                                }
                            })) {
                        Text(NSLocalizedString("settings.language.system", comment: "")).tag("system")
                        ForEach(LocaleService.supported, id: \.self) { code in
                            Text(localeService.displayName(for: code)).tag(code)
                        }
                    }
                }

                Section("Data") {
                    Text("\(store.expenses.count) expenses stored")
                        .foregroundStyle(.secondary)
                }

                if auth.isSignedIn {
                    Section {
                        Button(role: .destructive) {
                            auth.signOut()
                        } label: {
                            Text("Sign out")
                        }
                    }
                }

                Section {
                    Text("FacturaAI v1.0 · Kung Fu Software SL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSignIn) {
                SignInPrompt(
                    title: "Sign in",
                    subtitle: "Create an account to sync your expenses across devices, connect Gmail, and export to your accountant."
                )
            }
        }
    }
}

private struct TrialBanner: View {
    let daysLeft: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                Text("Your trial ends in \(daysLeft) day\(daysLeft == 1 ? "" : "s")")
                    .fontWeight(.semibold)
            }
            Text("Subscribe to keep using FacturaAI without interruptions.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            NavigationLink {
                PricingView()
            } label: {
                Text("View plans")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white)
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

struct PricingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose your plan")
                    .font(.largeTitle).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("No credit card during the 14-day trial.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PlanCard(
                    name: "Pro",
                    price: "€6.99/mo",
                    annual: "or €59/year (30% off)",
                    features: [
                        "Unlimited receipts",
                        "Daily automatic Gmail sync",
                        "Unlimited AI receipt scanning",
                        "CSV + Excel + Email export",
                        "Full Spanish tax categorization",
                    ],
                    highlighted: true,
                    badge: "Most popular"
                )
                PlanCard(
                    name: "Business",
                    price: "€12.99/mo",
                    annual: "or €109/year",
                    features: [
                        "Everything in Pro",
                        "Hourly Gmail sync",
                        "Accountant portal (read-only)",
                        "Up to 3 users",
                        "Bank connection PSD2 (coming soon)",
                    ],
                    highlighted: false,
                    badge: nil
                )
            }
            .padding()
        }
        .navigationTitle("Plans")
        .background(Color(.systemGroupedBackground))
    }
}

private struct PlanCard: View {
    let name: String
    let price: String
    let annual: String
    let features: [String]
    let highlighted: Bool
    let badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name).font(.title2).fontWeight(.bold)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.yellow)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }
            Text(price)
                .font(.title).fontWeight(.bold)
                .foregroundStyle(highlighted ? .white : .indigo)
            Text(annual)
                .font(.caption)
                .foregroundStyle(highlighted ? .white.opacity(0.85) : .secondary)
            Divider().background(highlighted ? .white.opacity(0.3) : .gray.opacity(0.3))
            ForEach(features, id: \.self) { f in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(f).font(.subheadline)
                }
                .foregroundStyle(highlighted ? .white : .primary)
            }
            Button {
                // TODO: wire StoreKit subscription flow
            } label: {
                Text("Subscribe")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(highlighted ? .white : Color.indigo)
                    .foregroundStyle(highlighted ? .indigo : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlighted
                      ? AnyShapeStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
        )
    }
}
