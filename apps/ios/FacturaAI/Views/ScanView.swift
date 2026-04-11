import SwiftUI
import PhotosUI
import VisionKit

struct ScanView: View {
    @EnvironmentObject var store: ExpenseStore
    @AppStorage("hasSeenAIDisclosure") private var hasSeenAIDisclosure = false
    @State private var showScanner = false
    @State private var showManual = false
    @State private var showPhotoPicker = false
    @State private var showDocPicker = false
    @State private var showCameraUnavailable = false
    @State private var showAIDisclosure = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scanning = false
    @State private var errorMessage: String?
    @State private var extractedExpense: Expense?
    @State private var showReview = false
    @State private var lastUploadedData: Data?
    @State private var showNotInvoice = false
    @State private var showFileTooLarge = false
    @State private var pendingExtraction: (data: Data, filename: String)?

    /// Maximum upload size: 20 MB
    private let maxUploadBytes = 20 * 1024 * 1024

    var body: some View {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.viewfinder.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.indigo)
                            .accessibilityHidden(true)
                            .padding(.top, 40)

                        Text(NSLocalizedString("scan.headline", comment: ""))
                            .font(.title2).fontWeight(.semibold)

                        Text(NSLocalizedString("scan.subtitle", comment: ""))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 32)

                        VStack(spacing: 12) {
                            Button {
                                if VNDocumentCameraViewController.isSupported {
                                    showScanner = true
                                } else {
                                    showCameraUnavailable = true
                                }
                            } label: {
                                Label(NSLocalizedString("scan.camera", comment: ""), systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)

                            Button {
                                showPhotoPicker = true
                            } label: {
                                Label(NSLocalizedString("scan.gallery", comment: ""), systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)

                            Button {
                                showDocPicker = true
                            } label: {
                                Label(NSLocalizedString("scan.pdf", comment: ""), systemImage: "doc.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)

                            Button {
                                showManual = true
                            } label: {
                                Label(NSLocalizedString("scan.manual", comment: ""), systemImage: "square.and.pencil")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top)

                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button { self.errorMessage = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel(NSLocalizedString("a11y.dismiss_error", comment: ""))
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 32)
                        }
                    }
                }
                .navigationTitle(NSLocalizedString("scan.title", comment: ""))
                .disabled(scanning)

                // Blocking extraction overlay
                if scanning {
                    ScanExtractionOverlay()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: scanning)
            .alert(NSLocalizedString("scan.camera_unavailable.title", comment: ""), isPresented: $showCameraUnavailable) {
                Button(NSLocalizedString("common.ok", comment: "")) {}
            } message: {
                Text(NSLocalizedString("scan.camera_unavailable.message", comment: ""))
            }
            .sheet(isPresented: $showScanner) {
                DocumentScanner { image in
                    guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                    startExtraction(data, filename: "scan_\(UUID().uuidString).jpg")
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) {
                guard let item = selectedPhotoItem else { return }
                selectedPhotoItem = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    startExtraction(data, filename: "photo_\(UUID().uuidString).jpg")
                }
            }
            .sheet(isPresented: $showDocPicker) {
                DocumentPicker { url in
                    guard let url else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    let filename = url.lastPathComponent
                    startFileExtraction(url, filename: filename)
                }
            }
            .sheet(isPresented: $showManual) {
                ManualEntryView()
            }
            .sheet(isPresented: $showReview, onDismiss: {
                extractedExpense = nil
                lastUploadedData = nil
            }) {
                if let expense = extractedExpense {
                    ReviewExtractedView(expense: expense, originalData: lastUploadedData) { confirmed in
                        if let confirmed {
                            store.add(confirmed)
                        }
                        // Don't clear extractedExpense here — the sheet needs it
                        // to show the success state. It gets cleared in onDismiss.
                    }
                }
            }
            .alert(NSLocalizedString("scan.not_invoice.title", comment: ""), isPresented: $showNotInvoice) {
                Button(NSLocalizedString("common.ok", comment: "")) {}
            } message: {
                Text(NSLocalizedString("scan.not_invoice.message", comment: ""))
            }
            .alert(NSLocalizedString("scan.ai_disclosure.title", comment: ""), isPresented: $showAIDisclosure) {
                Button(NSLocalizedString("scan.ai_disclosure.continue", comment: "")) {
                    hasSeenAIDisclosure = true
                    if let pending = pendingExtraction {
                        let data = pending.data
                        let filename = pending.filename
                        pendingExtraction = nil
                        Task { await extractData(data, filename: filename) }
                    }
                }
            } message: {
                Text(NSLocalizedString("scan.ai_disclosure.message", comment: ""))
            }
            .alert(NSLocalizedString("scan.file_too_large.title", comment: ""), isPresented: $showFileTooLarge) {
                Button(NSLocalizedString("common.ok", comment: "")) {}
            } message: {
                Text(NSLocalizedString("scan.file_too_large.message", comment: ""))
            }
            .onReceive(NotificationCenter.default.publisher(for: .scanAnother)) { _ in
                // Reset state so user can start a fresh scan
                extractedExpense = nil
                lastUploadedData = nil
                errorMessage = nil
            }
    }

    /// Gate extraction behind AI disclosure if needed, then proceed.
    private func startExtraction(_ data: Data, filename: String) {
        // Client-side file size check (20 MB limit)
        guard data.count <= maxUploadBytes else {
            showFileTooLarge = true
            return
        }
        if hasSeenAIDisclosure {
            Task { await extractData(data, filename: filename) }
        } else {
            pendingExtraction = (data, filename)
            showAIDisclosure = true
        }
    }

    /// Extract data from file — shows overlay, then presents review sheet.
    private func extractData(_ data: Data, filename: String) async {
        scanning = true
        errorMessage = nil
        lastUploadedData = data
        do {
            let expense = try await store.extractReceipt(data: data, filename: filename)
            scanning = false
            extractedExpense = expense
            showReview = true
        } catch let APIError.http(code, body) where code == 422 && body.contains("not_an_invoice") {
            scanning = false
            lastUploadedData = nil
            showNotInvoice = true
        } catch {
            scanning = false
            lastUploadedData = nil
            withAnimation { errorMessage = error.localizedDescription }
        }
    }

    /// File-based extraction — streams PDF without loading into memory.
    private func startFileExtraction(_ fileURL: URL, filename: String) {
        // Check file size without loading into memory
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int, size > maxUploadBytes {
            fileURL.stopAccessingSecurityScopedResource()
            showFileTooLarge = true
            return
        }
        Task {
            scanning = true
            errorMessage = nil
            lastUploadedData = nil
            do {
                let expense = try await store.extractReceiptFromFile(fileURL: fileURL, filename: filename)
                fileURL.stopAccessingSecurityScopedResource()
                scanning = false
                extractedExpense = expense
                showReview = true
            } catch let APIError.http(code, body) where code == 422 && body.contains("not_an_invoice") {
                fileURL.stopAccessingSecurityScopedResource()
                scanning = false
                showNotInvoice = true
            } catch {
                fileURL.stopAccessingSecurityScopedResource()
                scanning = false
                withAnimation { errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Review Extracted Expense

struct ReviewExtractedView: View {
    @State var expense: Expense
    let originalData: Data?
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    let onComplete: (Expense?) -> Void
    @State private var showOriginal = false
    @State private var confirmed = false

    /// True when neither vendor nor client matches the user's company name
    private var noCompanyMatch: Bool {
        guard let company = auth.companyName?.trimmingCharacters(in: .whitespaces).lowercased(),
              !company.isEmpty else { return false }
        let vendorMatch = expense.vendor.lowercased().contains(company) || company.contains(expense.vendor.lowercased())
        let clientMatch: Bool = {
            guard let client = expense.client?.trimmingCharacters(in: .whitespaces).lowercased(),
                  !client.isEmpty else { return false }
            return client.contains(company) || company.contains(client)
        }()
        return !vendorMatch && !clientMatch
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if confirmed {
                        // ── Success state ──
                        Spacer(minLength: 60)

                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 100, height: 100)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.green)
                        }

                        Text(NSLocalizedString("review.success.title", comment: ""))
                            .font(.title2.bold())

                        VStack(spacing: 4) {
                            Text(expense.vendor)
                                .font(.headline)
                            Text(Formatters.money(expense.total, currency: expense.currency))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.indigo)
                            Text(expense.category.localizedName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 40)

                        VStack(spacing: 12) {
                            Button {
                                let exp = expense
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    // Switch to Invoices tab and navigate to detail
                                    NotificationCenter.default.post(name: .switchToTab, object: 1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        NotificationCenter.default.post(name: .navigateToExpense, object: exp)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                    Text(NSLocalizedString("review.view_detail", comment: "")).fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.indigo)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    NotificationCenter.default.post(name: .scanAnother, object: nil)
                                }
                            } label: {
                                Text(NSLocalizedString("review.scan_another", comment: ""))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                    } else {
                        // ── Review state ──
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                        }
                        .padding(.top, 24)

                        Text(expense.type == .income
                             ? NSLocalizedString("review.title.income", comment: "")
                             : NSLocalizedString("review.title", comment: ""))
                            .font(.title3.bold())

                        if expense.type == .income {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(NSLocalizedString("transaction.income", comment: ""))
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        Text(NSLocalizedString("review.subtitle", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        // Confidence badge
                        HStack(spacing: 6) {
                            Image(systemName: confidenceIcon)
                                .foregroundStyle(confidenceColor)
                            Text(String(format: NSLocalizedString("review.confidence", comment: ""), Int(expense.confidence * 100)))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(confidenceColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(confidenceColor.opacity(0.1))
                        .clipShape(Capsule())

                        // Warning: invoice doesn't match user's company
                        if noCompanyMatch {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(NSLocalizedString("review.no_company_match", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 16)
                        }

                        // View original button
                        if originalData != nil {
                            Button {
                                showOriginal = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                    Text(NSLocalizedString("review.view_original", comment: ""))
                                }
                                .font(.subheadline)
                                .foregroundStyle(.indigo)
                            }
                        }

                        // Vendor section
                        sectionCard(title: NSLocalizedString("review.vendor", comment: ""), icon: "building.2.fill", color: .indigo) {
                            editableRow(NSLocalizedString("review.field.name", comment: ""), text: $expense.vendor)
                            Divider().padding(.leading, 16)
                            optionalEditableRow(NSLocalizedString("review.field.tax_id", comment: ""), text: bindingForOptional(\.vendorTaxId))
                        }

                        // Client section
                        sectionCard(title: NSLocalizedString("review.client", comment: ""), icon: "person.fill", color: .teal) {
                            optionalEditableRow(NSLocalizedString("review.field.name", comment: ""), text: bindingForOptional(\.client))
                            Divider().padding(.leading, 16)
                            optionalEditableRow(NSLocalizedString("review.field.tax_id", comment: ""), text: bindingForOptional(\.clientTaxId))
                        }

                        // Invoice details section
                        sectionCard(title: NSLocalizedString("review.invoice_details", comment: ""), icon: "doc.text.fill", color: .blue) {
                            readOnlyRow(NSLocalizedString("review.field.date", comment: ""), value: Formatters.shortDate.string(from: expense.date))
                            Divider().padding(.leading, 16)

                            if let invoiceNumber = expense.invoiceNumber, !invoiceNumber.isEmpty {
                                readOnlyRow(NSLocalizedString("review.field.invoice", comment: ""), value: invoiceNumber)
                                Divider().padding(.leading, 16)
                            }

                            readOnlyRow(NSLocalizedString("review.field.currency", comment: ""), value: expense.currency)
                        }

                        // Amounts section
                        sectionCard(title: NSLocalizedString("review.amounts", comment: ""), icon: "banknote.fill", color: .green) {
                            readOnlyRow(NSLocalizedString("review.field.subtotal", comment: ""), value: Formatters.money(expense.subtotal, currency: expense.currency))
                            Divider().padding(.leading, 16)

                            readOnlyRow(String(format: NSLocalizedString("review.field.tax", comment: ""), "\(expense.ivaRate)"), value: Formatters.money(expense.ivaAmount, currency: expense.currency))
                            Divider().padding(.leading, 16)

                            if expense.irpfAmount != 0 {
                                readOnlyRow(String(format: NSLocalizedString("review.field.withholding", comment: ""), "\(expense.irpfRate)"), value: Formatters.money(expense.irpfAmount, currency: expense.currency))
                                Divider().padding(.leading, 16)
                            }

                            HStack {
                                Text(NSLocalizedString("review.field.total", comment: ""))
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(Formatters.money(expense.total, currency: expense.currency))
                                    .fontWeight(.bold)
                                    .font(.title3)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // Category section
                        sectionCard(title: NSLocalizedString("review.classification", comment: ""), icon: "tag.fill", color: .orange) {
                            HStack {
                                Text(NSLocalizedString("review.field.category", comment: ""))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: $expense.category) {
                                    ForEach(TaxCategory.allCases, id: \.self) { c in
                                        Text(c.localizedName).tag(c)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // Action buttons
                        VStack(spacing: 12) {
                            Button {
                                expense.status = .confirmed
                                onComplete(expense)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    confirmed = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(NSLocalizedString("review.confirm", comment: "")).fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                onComplete(nil)
                                dismiss()
                            } label: {
                                Text(NSLocalizedString("review.discard", comment: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !confirmed {
                        Button(NSLocalizedString("common.cancel", comment: "")) {
                            onComplete(nil)
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showOriginal) {
                OriginalDocumentView(data: originalData!)
            }
        }
    }

    // MARK: - Section card

    @ViewBuilder
    private func sectionCard(title: String, icon: String, color: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            content()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private var confidenceIcon: String {
        if expense.confidence >= 0.9 { return "checkmark.seal.fill" }
        if expense.confidence >= 0.7 { return "exclamationmark.triangle.fill" }
        return "xmark.octagon.fill"
    }

    private var confidenceColor: Color {
        if expense.confidence >= 0.9 { return .green }
        if expense.confidence >= 0.7 { return .orange }
        return .red
    }

    @ViewBuilder
    private func readOnlyRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func editableRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func optionalEditableRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(NSLocalizedString("review.field.not_detected", comment: ""), text: text)
                .multilineTextAlignment(.trailing)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Creates a two-way binding for an optional String property, treating nil as empty string.
    private func bindingForOptional(_ keyPath: WritableKeyPath<Expense, String?>) -> Binding<String> {
        Binding(
            get: { expense[keyPath: keyPath] ?? "" },
            set: { expense[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Original Document Viewer

struct OriginalDocumentView: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isPDF {
                    PDFPreview(data: data)
                } else if let uiImage = UIImage(data: data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("review.original.unavailable", comment: ""))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("review.original.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "")) { dismiss() }
                }
            }
        }
    }

    private var isPDF: Bool {
        data.prefix(5) == Data("%PDF-".utf8)
    }
}

// MARK: - PDF Preview (using PDFKit)

import PDFKit

struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Scan Extraction Overlay

private struct ScanExtractionOverlay: View {
    @State private var phase = 0
    @State private var ringScale: CGFloat = 1.0

    private let steps: [(icon: String, text: String)] = [
        ("doc.text.magnifyingglass", NSLocalizedString("scan.extract.reading", comment: "")),
        ("cpu", NSLocalizedString("scan.extract.analyzing", comment: "")),
        ("text.viewfinder", NSLocalizedString("scan.extract.amounts", comment: "")),
        ("building.columns", NSLocalizedString("scan.extract.vendor", comment: "")),
        ("checkmark.seal", NSLocalizedString("scan.extract.verifying", comment: "")),
        ("sparkles", NSLocalizedString("scan.extract.almost", comment: "")),
    ]

    private var current: (icon: String, text: String) {
        steps[phase % steps.count]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.3), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)

                    Circle()
                        .fill(Color.indigo.opacity(0.1))
                        .frame(width: 88, height: 88)

                    Image(systemName: current.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                        .contentTransition(.symbolEffect(.replace))
                        .id(current.icon)
                }

                VStack(spacing: 8) {
                    Text(current.text)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: phase)
                        .id(current.text)

                    ScanBouncingDots()
                }

                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= phase % steps.count ? Color.indigo : Color(.systemGray4))
                            .frame(width: i == phase % steps.count ? 20 : 8, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: phase)
                    }
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                ringScale = 1.15
            }
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    phase += 1
                }
            }
        }
    }
}

private struct ScanBouncingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.indigo)
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
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
                Section(NSLocalizedString("manual.details", comment: "")) {
                    TextField(NSLocalizedString("manual.vendor", comment: ""), text: $vendor)
                    TextField(NSLocalizedString("manual.total", comment: ""), text: $total)
                        .keyboardType(.decimalPad)
                    DatePicker(NSLocalizedString("manual.date", comment: ""), selection: $date, displayedComponents: .date)
                    Picker(NSLocalizedString("manual.vat", comment: ""), selection: $ivaRate) {
                        Text("21%").tag(Decimal(21))
                        Text("10%").tag(Decimal(10))
                        Text("4%").tag(Decimal(4))
                        Text("0%").tag(Decimal(0))
                    }
                    Picker(NSLocalizedString("manual.category", comment: ""), selection: $category) {
                        ForEach(TaxCategory.allCases, id: \.self) { c in
                            Text(c.localizedName).tag(c)
                        }
                    }
                }
                Section {
                    Button(NSLocalizedString("manual.save", comment: "")) { save() }
                        .disabled(vendor.isEmpty || total.isEmpty)
                }
            }
            .navigationTitle(NSLocalizedString("manual.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
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

// MARK: - Document Scanner

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
