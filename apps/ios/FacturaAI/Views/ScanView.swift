import SwiftUI
import VisionKit

struct ScanView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var showScanner = false
    @State private var showManual = false
    @State private var showCameraUnavailable = false
    @State private var scanning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.indigo)
                        .padding(.top, 40)

                    Text("Scan a receipt or invoice")
                        .font(.title2).fontWeight(.semibold)

                    Text("Point the camera at the document. AI will automatically extract the data.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)

                    Button {
                        if VNDocumentCameraViewController.isSupported {
                            showScanner = true
                        } else {
                            showCameraUnavailable = true
                        }
                    } label: {
                        Label("Open camera", systemImage: "camera.fill")
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
                        Label("Enter manually", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.indigo)
                    .padding(.horizontal, 32)

                    if scanning {
                        HStack {
                            ProgressView()
                            Text("Extracting data with AI…").foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Scan")
            .alert("Camera not available", isPresented: $showCameraUnavailable) {
                Button("OK") {}
            } message: {
                Text("Document scanning is not available on this device.")
            }
            .sheet(isPresented: $showScanner) {
                DocumentScanner { image in
                    guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                    Task { await uploadScanned(data: data, filename: "scan_\(UUID().uuidString).jpg") }
                }
            }
            .sheet(isPresented: $showManual) {
                ManualEntryView()
            }
        }
    }

    private func uploadScanned(data: Data, filename: String) async {
        scanning = true
        do {
            _ = try await store.uploadReceipt(data: data, filename: filename)
        } catch {
            store.lastError = error.localizedDescription
        }
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
                Section("Details") {
                    TextField("Vendor", text: $vendor)
                    TextField("Total (€)", text: $total)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("VAT", selection: $ivaRate) {
                        Text("21%").tag(Decimal(21))
                        Text("10%").tag(Decimal(10))
                        Text("4%").tag(Decimal(4))
                        Text("0%").tag(Decimal(0))
                    }
                    Picker("Category", selection: $category) {
                        ForEach(TaxCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }
                Section {
                    Button("Save") { save() }
                        .disabled(vendor.isEmpty || total.isEmpty)
                }
            }
            .navigationTitle("New expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
