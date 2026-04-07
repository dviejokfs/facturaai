import SwiftUI

struct ExportView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var selectedQuarter: String = ""
    @State private var shareURL: URL?
    @State private var showShare = false

    var quarters: [String] {
        Array(Set(store.expenses.map { $0.quarter })).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Período") {
                    Picker("Trimestre", selection: $selectedQuarter) {
                        ForEach(quarters, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Resumen") {
                    let q = selectedQuarter.isEmpty ? store.currentQuarter() : selectedQuarter
                    row("Base imponible", Formatters.euro(store.totalSubtotal(for: q)))
                    row("IVA soportado", Formatters.euro(store.totalIVA(for: q)))
                    row("Total", Formatters.euro(store.totalAmount(for: q)))
                    row("Nº gastos", "\(store.expenses(in: q).count)")
                }

                Section("Exportar") {
                    Button {
                        exportCSV()
                    } label: {
                        Label("Descargar CSV", systemImage: "tablecells")
                    }
                    Button {
                        exportCSV()
                    } label: {
                        Label("Enviar a gestoría", systemImage: "paperplane.fill")
                    }
                }

                Section {
                    Text("El export incluye todos los gastos confirmados del trimestre seleccionado, con desglose de IVA listo para el modelo 303.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Exportar")
            .onAppear {
                if selectedQuarter.isEmpty {
                    selectedQuarter = store.currentQuarter()
                }
            }
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportCSV() {
        let q = selectedQuarter.isEmpty ? store.currentQuarter() : selectedQuarter
        let csv = CSVExporter.csv(for: store.expenses(in: q))
        if let url = CSVExporter.writeTempFile(csv: csv, name: "facturaai-\(q)") {
            shareURL = url
            showShare = true
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
