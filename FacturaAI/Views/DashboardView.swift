import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: ExpenseStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SummaryCard(
                        title: "Trimestre actual",
                        quarter: store.currentQuarter(),
                        subtotal: store.totalSubtotal(for: store.currentQuarter()),
                        iva: store.totalIVA(for: store.currentQuarter()),
                        total: store.totalAmount(for: store.currentQuarter())
                    )

                    SyncCard()

                    CategoryBreakdown(items: store.byCategory(for: store.currentQuarter()))

                    PendingReviewCard(count: store.expenses.filter { $0.status == .pending }.count)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resumen")
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let quarter: String
    let subtotal: Decimal
    let iva: Decimal
    let total: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(quarter).font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.15))
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
            }
            Text(Formatters.euro(total))
                .font(.system(size: 38, weight: .bold, design: .rounded))
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Base").font(.caption).foregroundStyle(.secondary)
                    Text(Formatters.euro(subtotal)).fontWeight(.semibold)
                }
                VStack(alignment: .leading) {
                    Text("IVA soportado").font(.caption).foregroundStyle(.secondary)
                    Text(Formatters.euro(iva)).fontWeight(.semibold).foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct SyncCard: View {
    @EnvironmentObject var store: ExpenseStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "envelope.badge.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Sincronizar Gmail").fontWeight(.semibold)
                Text(syncSubtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await store.syncGmail() }
            } label: {
                if store.isSyncing {
                    ProgressView()
                } else {
                    Text("Sincronizar").fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(store.isSyncing)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var syncSubtitle: String {
        if let d = store.lastSyncDate {
            return "Última: \(Formatters.shortDate.string(from: d))"
        }
        return "Nunca sincronizado"
    }
}

private struct CategoryBreakdown: View {
    let items: [(TaxCategory, Decimal)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Por categoría").font(.headline)
            if items.isEmpty {
                Text("Sin gastos todavía").foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Circle().fill(color(for: item.0)).frame(width: 10, height: 10)
                        Text(item.0.rawValue).font(.subheadline)
                        Spacer()
                        Text(Formatters.euro(item.1)).fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
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
                Text("\(count) gastos por revisar").fontWeight(.semibold)
                Text("Confirma o edita extracciones con baja confianza")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.12)))
    }
}
