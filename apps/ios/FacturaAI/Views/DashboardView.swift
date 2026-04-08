import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: ExpenseStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let q = store.currentQuarter()
                    let totals = store.totalsByCurrency(for: q)

                    if totals.isEmpty {
                        EmptyCard()
                    } else {
                        ForEach(totals) { t in
                            SummaryCard(quarter: q, totals: t)
                        }
                    }

                    SyncCard()

                    CategoryBreakdown(items: store.byCategory(for: store.currentQuarter()))

                    PendingReviewCard(count: store.expenses.filter { $0.status == .pending }.count)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
        }
    }
}

private struct SummaryCard: View {
    let quarter: String
    let totals: ExpenseStore.CurrencyTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current quarter · \(totals.currency)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(quarter).font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.15))
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
            }
            Text(Formatters.money(totals.total, currency: totals.currency))
                .font(.system(size: 38, weight: .bold, design: .rounded))
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Subtotal").font(.caption).foregroundStyle(.secondary)
                    Text(Formatters.money(totals.subtotal, currency: totals.currency))
                        .fontWeight(.semibold)
                }
                VStack(alignment: .leading) {
                    Text("Tax").font(.caption).foregroundStyle(.secondary)
                    Text(Formatters.money(totals.tax, currency: totals.currency))
                        .fontWeight(.semibold).foregroundStyle(.green)
                }
                VStack(alignment: .leading) {
                    Text("Invoices").font(.caption).foregroundStyle(.secondary)
                    Text("\(totals.count)").fontWeight(.semibold)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct EmptyCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No expenses this quarter yet").foregroundStyle(.secondary)
            Text("Scan a receipt or sync Gmail to get started")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct SyncCard: View {
    @EnvironmentObject var store: ExpenseStore
    @EnvironmentObject var auth: AuthService
    @State private var showSignIn = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "envelope.badge.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Sync Gmail").fontWeight(.semibold)
                Text(syncSubtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if auth.isSignedIn {
                    Task { await store.syncGmail() }
                } else {
                    showSignIn = true
                }
            } label: {
                if store.isSyncing {
                    ProgressView()
                } else {
                    Text("Sync").fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(store.isSyncing)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .sheet(isPresented: $showSignIn) {
            SignInPrompt(
                title: "Sign in to sync Gmail",
                subtitle: "Connect your Google account to automatically find and import invoices from your inbox."
            )
        }
    }

    private var syncSubtitle: String {
        if let d = store.lastSyncDate {
            return "Last: \(Formatters.shortDate.string(from: d))"
        }
        return "Never synced"
    }
}

private struct CategoryBreakdown: View {
    @EnvironmentObject var store: ExpenseStore
    let items: [(TaxCategory, Decimal)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By category").font(.headline)
            if items.isEmpty {
                Text("No expenses yet").foregroundStyle(.secondary)
            } else {
                // Per-category totals are mixed currencies — show raw amount + main currency hint
                ForEach(items, id: \.0) { item in
                    HStack {
                        Circle().fill(color(for: item.0)).frame(width: 10, height: 10)
                        Text(item.0.rawValue).font(.subheadline)
                        Spacer()
                        Text(Formatters.money(item.1, currency: primaryCurrency))
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var primaryCurrency: String {
        store.totalsByCurrency(for: store.currentQuarter()).first?.currency ?? "EUR"
    }

    private func color(for c: TaxCategory) -> Color {
        let palette: [Color] = [.indigo, .purple, .blue, .teal, .green, .orange, .pink, .red, .yellow, .mint]
        let idx = abs(c.rawValue.hashValue) % palette.count
        return palette[idx]
    }
}

private struct PendingReviewCard: View {
    let count: Int
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text("\(count) expenses to review").fontWeight(.semibold)
                Text("Confirm or edit low-confidence extractions")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.12)))
    }
}
