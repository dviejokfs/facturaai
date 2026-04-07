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

            Section("Datos fiscales") {
                if editing {
                    TextField("Proveedor", text: $expense.vendor)
                    TextField("CIF/NIF", text: Binding(
                        get: { expense.cif ?? "" },
                        set: { expense.cif = $0.isEmpty ? nil : $0 }))
                    TextField("Nº factura", text: Binding(
                        get: { expense.invoiceNumber ?? "" },
                        set: { expense.invoiceNumber = $0.isEmpty ? nil : $0 }))
                    DatePicker("Fecha", selection: $expense.date, displayedComponents: .date)
                    Picker("Categoría", selection: $expense.category) {
                        ForEach(TaxCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                } else {
                    row("CIF/NIF", expense.cif ?? "—")
                    row("Nº factura", expense.invoiceNumber ?? "—")
                    row("Fecha", Formatters.shortDate.string(from: expense.date))
                    row("Categoría", expense.category.rawValue)
                }
            }

            Section("Importes") {
                row("Base imponible", Formatters.euro(expense.subtotal))
                row("IVA (\(expense.ivaRate)%)", Formatters.euro(expense.ivaAmount))
                if expense.irpfAmount > 0 {
                    row("IRPF (\(expense.irpfRate)%)", "-" + Formatters.euro(expense.irpfAmount))
                }
                row("Total", Formatters.euro(expense.total)).fontWeight(.semibold)
            }

            if let name = expense.attachmentName {
                Section("Archivo adjunto") {
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
                        Label("Confirmar gasto", systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                }
                Button(role: .destructive) {
                    store.delete(expense)
                    dismiss()
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? "Guardar" : "Editar") {
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
