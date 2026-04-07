import SwiftUI
import VisionKit

struct ScanView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var showScanner = false
    @State private var showManual = false
    @State private var scanning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.indigo)
                        .padding(.top, 40)

                    Text("Escanea un ticket o factura")
                        .font(.title2).fontWeight(.semibold)

                    Text("Apunta con la cámara al documento. La IA extraerá automáticamente los datos.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)

                    Button {
                        showScanner = true
                    } label: {
                        Label("Abrir cámara", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .padding(.horizontal, 32)
                    .padding(.top)

                    Button {
                        showManual = true
                    } label: {
                        Label("Introducir manualmente", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.indigo)
                    .padding(.horizontal, 32)

                    if scanning {
                        HStack {
                            ProgressView()
                            Text("Extrayendo datos con IA…").foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Escanear")
            .sheet(isPresented: $showScanner) {
                DocumentScanner { _ in
                    Task { await simulateExtraction() }
                }
            }
            .sheet(isPresented: $showManual) {
                ManualEntryView()
            }
        }
    }

    private func simulateExtraction() async {
        scanning = true
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let new = Expense(
            vendor: "Ticket escaneado",
            cif: nil,
            date: Date(),
            invoiceNumber: nil,
            subtotal: 12.40,
            ivaRate: 10,
            ivaAmount: 1.24,
            irpfRate: 0,
            irpfAmount: 0,
            total: 13.64,
            category: .representacion,
            status: .pending,
            confidence: 0.78,
            source: .camera
        )
        store.add(new)
        scanning = false
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    var onScan: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let img = scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil
            controller.dismiss(animated: true) {
                self.parent.onScan(img)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

struct ManualEntryView: View {
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss

    @State private var vendor = ""
    @State private var total: String = ""
    @State private var ivaRate: Decimal = 21
    @State private var date = Date()
    @State private var category: TaxCategory = .otros

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Proveedor", text: $vendor)
                    TextField("Total (€)", text: $total)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    Picker("IVA", selection: $ivaRate) {
                        Text("21%").tag(Decimal(21))
                        Text("10%").tag(Decimal(10))
                        Text("4%").tag(Decimal(4))
                        Text("0%").tag(Decimal(0))
                    }
                    Picker("Categoría", selection: $category) {
                        ForEach(TaxCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }
                Section {
                    Button("Guardar") { save() }
                        .disabled(vendor.isEmpty || total.isEmpty)
                }
            }
            .navigationTitle("Nuevo gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let totalDec = Decimal(string: total.replacingOccurrences(of: ",", with: ".")) ?? 0
        let base = totalDec / (1 + ivaRate / 100)
        let iva = totalDec - base
        let e = Expense(
            vendor: vendor, cif: nil, date: date, invoiceNumber: nil,
            subtotal: base, ivaRate: ivaRate, ivaAmount: iva,
            irpfRate: 0, irpfAmount: 0, total: totalDec,
            category: category, status: .confirmed, confidence: 1.0, source: .manual
        )
        store.add(e)
        dismiss()
    }
}
