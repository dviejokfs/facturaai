import SwiftUI

struct CountryPickerView: View {
    @Binding var selected: TaxCountry
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [TaxCountry] {
        if searchText.isEmpty { return TaxCountry.allCases }
        let q = searchText.lowercased()
        return TaxCountry.allCases.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.taxIdLabel.lowercased().contains(q) ||
            $0.taxIdType.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { country in
                    Button {
                        selected = country
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(country.flag)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.displayName)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(country.taxIdLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if country == selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: NSLocalizedString("onboarding.company.search_country", comment: ""))
            .navigationTitle(NSLocalizedString("onboarding.company.country_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", comment: "")) { dismiss() }
                }
            }
        }
    }
}
