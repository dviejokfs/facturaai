import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject var store: ExpenseStore
    var onScanTap: (() -> Void)? = nil
    @State private var searchText = ""
    @State private var filter: ExpenseStatus? = nil
    @State private var typeFilter: TransactionType? = nil
    @State private var quarterFilter: String? = nil
    @State private var navigationPath = NavigationPath()

    private var availableQuarters: [String] {
        let all = Set(store.expenses.map { $0.quarter })
        return all.sorted().reversed()
    }

    private var hasAnyFilter: Bool {
        filter != nil || typeFilter != nil || quarterFilter != nil
    }

    var filtered: [Expense] {
        store.expenses.filter { e in
            (quarterFilter == nil || e.quarter == quarterFilter) &&
            (filter == nil || e.status == filter) &&
            (typeFilter == nil || e.type == typeFilter) &&
            (searchText.isEmpty || e.vendor.localizedCaseInsensitiveContains(searchText) ||
             (e.client?.localizedCaseInsensitiveContains(searchText) ?? false))
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Quarter chips
                        ForEach(availableQuarters, id: \.self) { q in
                            FilterChip(
                                label: q,
                                icon: "calendar",
                                isSelected: quarterFilter == q,
                                color: .indigo
                            ) {
                                quarterFilter = quarterFilter == q ? nil : q
                            }
                        }

                        if availableQuarters.count > 0 {
                            Divider().frame(height: 20)
                        }

                        // Type chips
                        FilterChip(
                            label: NSLocalizedString("transaction.expense", comment: ""),
                            icon: "arrow.up.right",
                            isSelected: typeFilter == .expense,
                            color: .indigo
                        ) {
                            typeFilter = typeFilter == .expense ? nil : .expense
                        }

                        FilterChip(
                            label: NSLocalizedString("transaction.income", comment: ""),
                            icon: "arrow.down.left",
                            isSelected: typeFilter == .income,
                            color: .green
                        ) {
                            typeFilter = typeFilter == .income ? nil : .income
                        }

                        Divider().frame(height: 20)

                        // Status chips
                        FilterChip(
                            label: NSLocalizedString("expenses.filter.pending", comment: ""),
                            icon: "clock",
                            isSelected: filter == .pending,
                            color: .orange
                        ) {
                            filter = filter == .pending ? nil : .pending
                        }

                        FilterChip(
                            label: NSLocalizedString("expenses.filter.confirmed", comment: ""),
                            icon: "checkmark",
                            isSelected: filter == .confirmed,
                            color: .green
                        ) {
                            filter = filter == .confirmed ? nil : .confirmed
                        }

                        if hasAnyFilter {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    quarterFilter = nil
                                    typeFilter = nil
                                    filter = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel(NSLocalizedString("a11y.clear_filters", comment: ""))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("expenses.empty.title", comment: ""))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(NSLocalizedString("expenses.empty.subtitle", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            onScanTap?()
                        } label: {
                            Label(NSLocalizedString("expenses.empty.scan", comment: ""), systemImage: "camera.fill")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.indigo)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { e in
                            NavigationLink(value: e) {
                                ExpenseRow(expense: e)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        store.reject(e)
                                    }
                                } label: { Label(NSLocalizedString("expenses.reject", comment: ""), systemImage: "xmark") }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        store.confirm(e)
                                    }
                                } label: { Label(NSLocalizedString("expenses.confirm", comment: ""), systemImage: "checkmark") }
                                .tint(.green)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: NSLocalizedString("expenses.search", comment: ""))
            .navigationTitle(NSLocalizedString("expenses.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Expense.self) { ExpenseDetailView(expense: $0) }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToExpense)) { notif in
                if let expense = notif.object as? Expense {
                    // Clear any existing path first, then navigate
                    navigationPath = NavigationPath()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigationPath.append(expense)
                    }
                }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? color.opacity(0.15) : Color(.secondarySystemFill))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: expense.source.icon)
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .frame(width: 40, height: 40)
                    .background(Color.indigo.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if expense.type == .income {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .background(Circle().fill(Color(.systemBackground)).frame(width: 12, height: 12))
                        .offset(x: 2, y: 2)
                        .accessibilityLabel(NSLocalizedString("a11y.income_indicator", comment: ""))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.type == .income
                     ? (expense.client ?? expense.vendor)
                     : expense.vendor)
                    .fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 6) {
                    Text(Formatters.shortDate.string(from: expense.date))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("•").font(.caption).foregroundStyle(.secondary)
                    Text(expense.category.localizedName)
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
            Text(NSLocalizedString("expenses.status.pending", comment: "")).font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.orange.opacity(0.18))
                .foregroundStyle(.orange).clipShape(Capsule())
        case .confirmed:
            Text(NSLocalizedString("expenses.status.confirmed", comment: "")).font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.green.opacity(0.18))
                .foregroundStyle(.green).clipShape(Capsule())
        case .rejected:
            Text(NSLocalizedString("expenses.status.rejected", comment: "")).font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.red.opacity(0.18))
                .foregroundStyle(.red).clipShape(Capsule())
        }
    }
}
