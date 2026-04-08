import SwiftUI

struct AccountantSettingsView: View {
    @EnvironmentObject var auth: AuthService
    @State private var accountantName: String = ""
    @State private var accountantEmail: String = ""
    @State private var taxId: String = ""
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                Text(NSLocalizedString("accountant.description", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(NSLocalizedString("accountant.section.accountant", comment: "")) {
                TextField(NSLocalizedString("accountant.name.placeholder", comment: ""),
                          text: $accountantName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                TextField(NSLocalizedString("accountant.email.placeholder", comment: ""),
                          text: $accountantEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            Section(NSLocalizedString("accountant.section.tax", comment: "")) {
                TextField(NSLocalizedString("accountant.taxid.placeholder", comment: ""),
                          text: $taxId)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Text(NSLocalizedString("accountant.save", comment: ""))
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else if saved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle(NSLocalizedString("accountant.title", comment: ""))
        .onAppear { loadFromProfile() }
    }

    private func loadFromProfile() {
        accountantName = auth.accountantName ?? ""
        accountantEmail = auth.accountantEmail ?? ""
        taxId = auth.taxId ?? ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            var fields: [String: Any] = [:]
            fields["accountant_name"] = accountantName
            fields["accountant_email"] = accountantEmail
            fields["tax_id"] = taxId
            try await APIClient.shared.updateProfile(fields)
            auth.accountantName = accountantName
            auth.accountantEmail = accountantEmail
            auth.taxId = taxId
            saved = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            saved = false
        } catch {
            // silent — user can retry
        }
    }
}
