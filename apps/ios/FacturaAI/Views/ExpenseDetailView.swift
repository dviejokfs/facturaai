import SwiftUI
import PDFKit

struct ExpenseDetailView: View {
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @State var expense: Expense
    @State private var editing = false
    @State private var attachmentData: Data?
    @State private var attachmentContentType: String?
    @State private var isLoadingAttachment = false
    @State private var attachmentError: String?
    @State private var showShareSheet = false
    @State private var shareFileURL: URL?

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: expense.source.icon)
                        .foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.type == .income
                             ? (expense.client ?? expense.vendor)
                             : expense.vendor)
                            .font(.headline)
                        if expense.type == .income {
                            Text(NSLocalizedString("transaction.income", comment: ""))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }
                    Spacer()
                    ConfidenceBadge(value: expense.confidence)
                }
            }

            Section(NSLocalizedString("detail.tax_details", comment: "")) {
                if editing {
                    TextField(NSLocalizedString("manual.vendor", comment: ""), text: $expense.vendor)
                    TextField(NSLocalizedString("detail.tax_id", comment: ""), text: Binding(
                        get: { expense.cif ?? "" },
                        set: { expense.cif = $0.isEmpty ? nil : $0 }))
                    TextField(NSLocalizedString("detail.invoice", comment: ""), text: Binding(
                        get: { expense.invoiceNumber ?? "" },
                        set: { expense.invoiceNumber = $0.isEmpty ? nil : $0 }))
                    DatePicker(NSLocalizedString("detail.date", comment: ""), selection: $expense.date, displayedComponents: .date)
                    Picker(NSLocalizedString("detail.category", comment: ""), selection: $expense.category) {
                        ForEach(TaxCategory.allCases, id: \.self) { c in
                            Text(c.localizedName).tag(c)
                        }
                    }
                } else {
                    if expense.type == .income {
                        row(NSLocalizedString("detail.vendor", comment: ""), expense.vendor)
                        if let clientTaxId = expense.clientTaxId, !clientTaxId.isEmpty {
                            row(NSLocalizedString("detail.client_tax_id", comment: ""), clientTaxId)
                        }
                    }
                    row(NSLocalizedString("detail.tax_id", comment: ""), expense.cif ?? "—")
                    row(NSLocalizedString("detail.invoice", comment: ""), expense.invoiceNumber ?? "—")
                    row(NSLocalizedString("detail.date", comment: ""), Formatters.shortDate.string(from: expense.date))
                    row(NSLocalizedString("detail.category", comment: ""), expense.category.localizedName)
                }
            }

            Section(NSLocalizedString("detail.amounts", comment: "")) {
                row(NSLocalizedString("detail.subtotal", comment: ""), Formatters.money(expense.subtotal, currency: expense.currency))
                row(String(format: NSLocalizedString("detail.tax_rate", comment: ""), "\(expense.ivaRate)"), Formatters.money(expense.ivaAmount, currency: expense.currency))
                if expense.irpfAmount > 0 {
                    row(String(format: NSLocalizedString("detail.withholding_rate", comment: ""), "\(expense.irpfRate)"), "-" + Formatters.money(expense.irpfAmount, currency: expense.currency))
                }
                row(NSLocalizedString("detail.total", comment: ""), Formatters.money(expense.total, currency: expense.currency)).fontWeight(.semibold)
            }

            // Inline attachment viewer
            if expense.hasRemoteAttachment || expense.attachmentName != nil {
                Section(NSLocalizedString("detail.attachment", comment: "")) {
                    if isLoadingAttachment {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else if let error = attachmentError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else if let data = attachmentData, let type = attachmentContentType {
                        // Inline preview
                        if type.contains("pdf") {
                            PDFPreview(data: data)
                                .frame(minHeight: 400)
                                .listRowInsets(EdgeInsets())
                        } else if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .listRowInsets(EdgeInsets())
                        }

                        // Share/download button
                        Button {
                            shareAttachment(data: data, contentType: type)
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text(NSLocalizedString("detail.attachment.share", comment: ""))
                            }
                        }
                        .accessibilityLabel(NSLocalizedString("a11y.share_attachment", comment: ""))
                    } else {
                        // Not yet loaded — trigger on appear
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await loadAttachment() }
                            }
                    }
                }
            }

            Section {
                if expense.status != .confirmed {
                    Button {
                        store.confirm(expense)
                        dismiss()
                    } label: {
                        Label(NSLocalizedString("detail.confirm", comment: ""), systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                }
                Button(role: .destructive) {
                    store.delete(expense)
                    dismiss()
                } label: {
                    Label(NSLocalizedString("common.delete", comment: ""), systemImage: "trash")
                }
            }
        }
        .navigationTitle(NSLocalizedString("detail.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? NSLocalizedString("detail.save", comment: "") : NSLocalizedString("detail.edit", comment: "")) {
                    if editing { store.update(expense) }
                    editing.toggle()
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Attachment

    private func loadAttachment() async {
        guard attachmentData == nil, !isLoadingAttachment else { return }
        isLoadingAttachment = true
        defer { isLoadingAttachment = false }
        do {
            let (data, contentType) = try await APIClient.shared.downloadAttachment(expenseId: expense.id.uuidString)
            attachmentData = data
            attachmentContentType = contentType
        } catch let APIError.http(code, _) where code == 404 {
            attachmentError = NSLocalizedString("detail.attachment.not_found", comment: "")
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    private func shareAttachment(data: Data, contentType: String) {
        let ext = contentType.contains("pdf") ? "pdf" : contentType.contains("png") ? "png" : "jpg"
        let filename = expense.attachmentName ?? "invoice.\(ext)"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tmpURL)
        shareFileURL = tmpURL
        showShareSheet = true
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
