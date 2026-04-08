import SwiftUI

struct ExpenseDetailView: View {
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @State var expense: Expense
    @State private var editing = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: expense.source.icon)
                        .foregroundStyle(.indigo)
                    Text(expense.vendor).font(.headline)
                    Spacer()
                    ConfidenceBadge(value: expense.confidence)
                }
            }

            Section("Tax details") {
                if editing {
                    TextField("Vendor", text: $expense.vendor)
                    TextField("Tax ID", text: Binding(
                        get: { expense.cif ?? "" },
                        set: { expense.cif = $0.isEmpty ? nil : $0 }))
                    TextField("Invoice #", text: Binding(
                        get: { expense.invoiceNumber ?? "" },
                        set: { expense.invoiceNumber = $0.isEmpty ? nil : $0 }))
                    DatePicker("Date", selection: $expense.date, displayedComponents: .date)
                    Picker("Category", selection: $expense.category) {
                        ForEach(TaxCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                } else {
                    row("Tax ID", expense.cif ?? "—")
                    row("Invoice #", expense.invoiceNumber ?? "—")
                    row("Date", Formatters.shortDate.string(from: expense.date))
                    row("Category", expense.category.rawValue)
                }
            }

            Section("Amounts") {
                row("Subtotal", Formatters.money(expense.subtotal, currency: expense.currency))
                row("Tax (\(expense.ivaRate)%)", Formatters.money(expense.ivaAmount, currency: expense.currency))
                if expense.irpfAmount > 0 {
                    row("Withholding (\(expense.irpfRate)%)", "-" + Formatters.money(expense.irpfAmount, currency: expense.currency))
                }
                row("Total", Formatters.money(expense.total, currency: expense.currency)).fontWeight(.semibold)
            }

            if let name = expense.attachmentName {
                Section("Attachment") {
                    HStack {
                        Image(systemName: "doc.fill").foregroundStyle(.indigo)
                        Text(name)
                    }
                }
            }

            Section {
                if expense.status != .confirmed {
                    Button {
                        store.confirm(expense)
                        dismiss()
                    } label: {
                        Label("Confirm expense", systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                }
                Button(role: .destructive) {
                    store.delete(expense)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? "Save" : "Edit") {
                    if editing { store.update(expense) }
                    editing.toggle()
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

private struct ConfidenceBadge: View {
    let value: Double
    var body: some View {
        let pct = Int(value * 100)
        let color: Color = value > 0.9 ? .green : (value > 0.75 ? .orange : .red)
        Text("\(pct)%")
            .font(.caption2).fontWeight(.bold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
