import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ExpenseStore
    @StateObject private var localeService = LocaleService.shared
    @State private var showSignIn = false
    @State private var showGmailSync = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var isExportingData = false
    @State private var exportedFileURL: URL?
    @State private var showExportShare = false
    @State private var showExportError = false
    @State private var restoringPurchases = false
    @State private var showRestoreResult = false
    @State private var restoreSuccess = false
    @AppStorage("hasCompletedFirstUse") private var hasCompletedFirstUse = true

    var planLabel: String {
        switch auth.plan {
        case "trial": return String(format: NSLocalizedString("settings.plan.trial", comment: ""), auth.trialDaysLeft)
        case "pro": return NSLocalizedString("settings.plan.pro", comment: "")
        case "business": return NSLocalizedString("settings.plan.business", comment: "")
        case "expired": return NSLocalizedString("settings.plan.expired", comment: "")
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
                                    Text(NSLocalizedString("settings.signIn", comment: "")).fontWeight(.semibold)
                                    Text(NSLocalizedString("settings.signIn.subtitle", comment: ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if auth.isSignedIn, auth.trialExpired {
                    Section {
                        ExpiredTrialBanner()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } else if auth.isSignedIn, auth.plan == "trial", auth.trialDaysLeft <= 5 {
                    Section {
                        TrialBanner(daysLeft: auth.trialDaysLeft)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if auth.isSignedIn {
                    Section(NSLocalizedString("settings.account", comment: "")) {
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

                    Section(NSLocalizedString("settings.companies", comment: "")) {
                        NavigationLink {
                            CompanyNameView()
                        } label: {
                            HStack {
                                Image(systemName: "building.2.fill").foregroundStyle(.indigo)
                                VStack(alignment: .leading) {
                                    Text(NSLocalizedString("settings.company_name", comment: ""))
                                    Text(auth.companyName ?? NSLocalizedString("settings.company_name.not_set", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(auth.companyName != nil ? .secondary : .orange)
                                }
                            }
                        }

                        NavigationLink {
                            ContactsView()
                        } label: {
                            HStack {
                                Image(systemName: "person.2.fill").foregroundStyle(.teal)
                                Text(NSLocalizedString("contacts.title", comment: ""))
                            }
                        }
                    }

                    Section(NSLocalizedString("settings.integrations", comment: "")) {
                        Button {
                            showGmailSync = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill").foregroundStyle(.red)
                                Text("Gmail")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.isSyncing, let progress = store.syncProgress {
                                    GmailSyncBadge(progress: progress)
                                } else {
                                    Text(auth.gmailConnected ? NSLocalizedString("settings.gmail.connected", comment: "") : NSLocalizedString("settings.gmail.not_connected", comment: ""))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(auth.gmailConnected ? .green : .secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        HStack {
                            Image(systemName: "folder.fill").foregroundStyle(.blue)
                            Text(NSLocalizedString("settings.integration.gdrive", comment: ""))
                            Spacer()
                            Text(NSLocalizedString("settings.coming_soon", comment: "")).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Image(systemName: "building.columns.fill").foregroundStyle(.teal)
                            Text(NSLocalizedString("settings.integration.bank", comment: ""))
                            Spacer()
                            Text(NSLocalizedString("settings.coming_soon", comment: "")).font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Section(NSLocalizedString("settings.plan", comment: "")) {
                        NavigationLink {
                            PricingView()
                        } label: {
                            Label(auth.plan == "pro" || auth.plan == "business"
                                  ? NSLocalizedString("settings.plan.change", comment: "")
                                  : NSLocalizedString("settings.plan.view", comment: ""),
                                  systemImage: "sparkles")
                        }
                        Button {
                            Task {
                                restoringPurchases = true
                                restoreSuccess = await RevenueCatService.shared.restorePurchases()
                                restoringPurchases = false
                                showRestoreResult = true
                            }
                        } label: {
                            if restoringPurchases {
                                HStack {
                                    Label(NSLocalizedString("settings.restorePurchases", comment: ""), systemImage: "arrow.clockwise")
                                    Spacer()
                                    ProgressView()
                                }
                            } else {
                                Label(NSLocalizedString("settings.restorePurchases", comment: ""), systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(restoringPurchases)
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            Label(NSLocalizedString("settings.manageSubscription", comment: ""), systemImage: "creditcard")
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

                Section(NSLocalizedString("settings.data", comment: "")) {
                    Text(String(format: NSLocalizedString("settings.expenses_count", comment: ""), store.expenses.count))
                        .foregroundStyle(.secondary)

                    if auth.isSignedIn {
                        Button {
                            Task {
                                isExportingData = true
                                do {
                                    let url = try await APIClient.shared.exportPersonalData()
                                    exportedFileURL = url
                                    showExportShare = true
                                } catch {
                                    print("[Settings] Data export failed: \(error)")
                                    showExportError = true
                                }
                                isExportingData = false
                            }
                        } label: {
                            HStack {
                                if isExportingData {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Label(NSLocalizedString("settings.downloadData", comment: ""), systemImage: "arrow.down.doc.fill")
                            }
                        }
                        .disabled(isExportingData)
                    }
                }

                if auth.isSignedIn {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAccountAlert = true
                        } label: {
                            if isDeletingAccount {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(NSLocalizedString("settings.deleteAccount", comment: ""))
                                }
                            } else {
                                Text(NSLocalizedString("settings.deleteAccount", comment: ""))
                            }
                        }
                        .disabled(isDeletingAccount)
                        .alert(
                            NSLocalizedString("settings.deleteAccount.title", comment: ""),
                            isPresented: $showDeleteAccountAlert
                        ) {
                            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
                            Button(NSLocalizedString("settings.deleteAccount.confirm", comment: ""), role: .destructive) {
                                Task {
                                    isDeletingAccount = true
                                    do {
                                        try await APIClient.shared.deleteAccount()
                                        hasCompletedFirstUse = false
                                        auth.signOut()
                                    } catch {
                                        print("[Settings] Account deletion failed: \(error)")
                                    }
                                    isDeletingAccount = false
                                }
                            }
                        } message: {
                            Text(NSLocalizedString("settings.deleteAccount.message", comment: ""))
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            auth.signOut()
                        } label: {
                            Text(NSLocalizedString("settings.signOut", comment: ""))
                        }
                    }
                }

                Section {
                    Text(NSLocalizedString("settings.app_version", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .sheet(isPresented: $showSignIn) {
                SignInPrompt(
                    title: NSLocalizedString("signIn.title", comment: ""),
                    subtitle: NSLocalizedString("signIn.subtitle", comment: "")
                )
            }
            .sheet(isPresented: $showGmailSync) {
                GmailSyncView()
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert(NSLocalizedString("settings.downloadData.error", comment: ""), isPresented: $showExportError) {
                Button(NSLocalizedString("common.ok", comment: "")) {}
            }
            .alert(
                restoreSuccess
                    ? NSLocalizedString("restore.success.title", comment: "")
                    : NSLocalizedString("restore.empty.title", comment: ""),
                isPresented: $showRestoreResult
            ) {
                Button(NSLocalizedString("common.ok", comment: "")) {}
            } message: {
                Text(restoreSuccess
                     ? NSLocalizedString("restore.success.message", comment: "")
                     : NSLocalizedString("restore.empty.message", comment: ""))
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
                Text(String(format: NSLocalizedString("settings.trial_banner.title", comment: ""), daysLeft))
                    .fontWeight(.semibold)
            }
            Text(NSLocalizedString("settings.trial_banner.subtitle", comment: ""))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            NavigationLink {
                PricingView()
            } label: {
                Text(NSLocalizedString("settings.trial_banner.cta", comment: ""))
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

private struct ExpiredTrialBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                Text(NSLocalizedString("paywall.trial_expired.title", comment: ""))
                    .font(.headline).fontWeight(.bold)
            }
            Text(NSLocalizedString("paywall.trial_expired.message", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            NavigationLink {
                PricingView()
            } label: {
                Text(NSLocalizedString("paywall.subscribe", comment: ""))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.white)
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

struct PricingView: View {
    var body: some View {
        PaywallSheet(placement: .manage)
    }
}

private struct GmailSyncBadge: View {
    let progress: ExpenseStore.GmailSyncProgress

    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
            if progress.totalMessages > 0 {
                Text("\(progress.messagesProcessed)/\(progress.totalMessages)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
            } else {
                Text(NSLocalizedString("dashboard.sync.scanning", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.indigo.opacity(0.1))
        .clipShape(Capsule())
    }
}
