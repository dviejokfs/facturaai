import SwiftUI

struct CompanyNameView: View {
    @EnvironmentObject var auth: AuthService
    @State private var companyName: String = ""
    @State private var taxId: String = ""
    @State private var selectedCountry: TaxCountry = .spain
    @State private var showCountryPicker = false
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.indigo)
                    Text(NSLocalizedString("company.setup.title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("company.setup.subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section(NSLocalizedString("company.name.section", comment: "")) {
                TextField(NSLocalizedString("company.name.placeholder", comment: ""), text: $companyName)
                    .textInputAutocapitalization(.words)
            }

            Section(NSLocalizedString("onboarding.company.country_label", comment: "")) {
                Button {
                    showCountryPicker = true
                } label: {
                    HStack {
                        Text(selectedCountry.flag).font(.title3)
                        Text(selectedCountry.displayName).foregroundStyle(.primary)
                        Spacer()
                        Text(selectedCountry.taxIdLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(selectedCountry.taxIdLabel) {
                TextField(selectedCountry.taxIdPlaceholder, text: $taxId)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(saved
                             ? NSLocalizedString("company.saved", comment: "")
                             : NSLocalizedString("common.save", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(companyName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }

            Section {
                Text(NSLocalizedString("company.explanation", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(NSLocalizedString("settings.company_name", comment: ""))
        .onAppear {
            companyName = auth.companyName ?? ""
            taxId = auth.taxId ?? ""
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selected: $selectedCountry)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let nameTrimmed = companyName.trimmingCharacters(in: .whitespaces)
        let taxTrimmed = taxId.trimmingCharacters(in: .whitespaces)
        do {
            var fields: [String: Any] = [
                "company_name": nameTrimmed,
                "tax_id_type": selectedCountry.taxIdType,
            ]
            if !taxTrimmed.isEmpty { fields["tax_id"] = taxTrimmed }
            try await APIClient.shared.updateProfile(fields)
            auth.companyName = nameTrimmed
            auth.taxId = taxTrimmed.isEmpty ? nil : taxTrimmed
            saved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
        } catch {
            print("[CompanyNameView] save error: \(error)")
        }
    }
}
