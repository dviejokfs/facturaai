import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var searchText = ""
    @State private var filter: ExpenseStatus? = nil

    var filtered: [Expense] {
        store.expenses.filter { e in
            (filter == nil || e.status == filter) &&
            (searchText.isEmpty || e.vendor.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    Text("All").tag(ExpenseStatus?.none)
                    Text("Pending").tag(ExpenseStatus?.some(.pending))
                    Text("Confirmed").tag(ExpenseStatus?.some(.confirmed))
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    ForEach(filtered) { e in
                        NavigationLink(value: e) {
                            ExpenseRow(expense: e)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.reject(e)
                            } label: { Label("Reject", systemImage: "xmark") }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                store.confirm(e)
                            } label: { Label("Confirm", systemImage: "checkmark") }
                            .tint(.green)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search vendor")
            .navigationTitle("Expenses")
            .navigationDestination(for: Expense.self) { ExpenseDetailView(expense: $0) }
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.source.icon)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 40, height: 40)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.vendor).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 6) {
                    Text(Formatters.shortDate.string(from: expense.date))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("•").font(.caption).foregroundStyle(.secondary)
                    Text(expense.category.rawValue)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Formatters.money(expense.total, currency: expense.currency)).fontWeight(.semibold)
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder var statusBadge: some View {
        switch expense.status {
        case .pending:
            Text("Pending").font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.orange.opacity(0.18))
                .foregroundStyle(.orange).clipShape(Capsule())
        case .confirmed:
            Text("OK").font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.green.opacity(0.18))
                .foregroundStyle(.green).clipShape(Capsule())
        case .rejected:
            Text("Rejected").font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.red.opacity(0.18))
                .foregroundStyle(.red).clipShape(Capsule())
        }
    }
}
