import SwiftUI

struct ContactsView: View {
    @State private var contacts: [RemoteContact] = []
    @State private var searchText = ""
    @State private var isLoading = false

    var body: some View {
        List {
            if contacts.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("contacts.empty", comment: ""))
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("contacts.empty.subtitle", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            }

            ForEach(contacts) { contact in
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.teal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).fontWeight(.semibold)
                        if let taxId = contact.taxId, !taxId.isEmpty {
                            Text(taxId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let email = contact.email, !email.isEmpty {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await deleteContact(contact) }
                    } label: {
                        Label(NSLocalizedString("common.delete", comment: ""), systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("contacts.title", comment: ""))
        .searchable(text: $searchText, prompt: NSLocalizedString("contacts.search", comment: ""))
        .onChange(of: searchText) {
            Task { await loadContacts() }
        }
        .task { await loadContacts() }
        .overlay {
            if isLoading && contacts.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            contacts = try await APIClient.shared.listContacts(query: searchText.isEmpty ? nil : searchText)
        } catch {
            print("[ContactsView] load error: \(error)")
        }
    }

    private func deleteContact(_ contact: RemoteContact) async {
        do {
            try await APIClient.shared.deleteContact(id: contact.id)
            await loadContacts()
        } catch {
            print("[ContactsView] delete error: \(error)")
        }
    }
}
