import SwiftUI
import MessageUI

// MARK: - ExportView

struct ExportView: View {
    @EnvironmentObject var store: ExpenseStore
    @EnvironmentObject var auth: AuthService
    @State private var selectedQuarter: String = ""
    @State private var exportJob: ExportJob?
    @State private var phase: ExportPhase = .preview
    @State private var shareURL: URL?
    @State private var shareLink: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAccountantPrompt = false
    @State private var showShareSheet = false
    @State private var showMailComposer = false
    @State private var showLinkCopied = false
    @State private var showSignIn = false
    @State private var isSendingEmail = false
    @State private var emailSent = false
    @State private var warningReviewExpenses: [Expense] = []
    @State private var warningReviewTitle: String = ""
    @State private var showWarningReview = false

    enum ExportPhase {
        case preview
        case generating
        case success
    }

    var quarters: [String] {
        let fromExpenses = Set(store.expenses.map { $0.quarter })
        let current = store.currentQuarter()
        return Array(fromExpenses.union([current])).sorted(by: >)
    }

    var currentQ: String {
        selectedQuarter.isEmpty ? store.currentQuarter() : selectedQuarter
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signInRequired
                } else {
                    switch phase {
                    case .preview:
                        previewContent
                    case .generating:
                        generatingContent
                    case .success:
                        successContent
                    }
                }
            }
            .navigationTitle(NSLocalizedString("export.title", comment: ""))
            .onAppear {
                if selectedQuarter.isEmpty {
                    selectedQuarter = store.currentQuarter()
                }
            }
            .sheet(isPresented: $showAccountantPrompt) {
                NavigationStack {
                    AccountantSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(NSLocalizedString("common.close", comment: "")) {
                                    showAccountantPrompt = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showMailComposer) {
                if let url = shareURL, MFMailComposeViewController.canSendMail() {
                    MailComposer(
                        toRecipients: [auth.accountantEmail ?? ""],
                        subject: NSLocalizedString("export.email.subject", comment: "")
                            .replacingOccurrences(of: "{quarter}", with: currentQ),
                        body: NSLocalizedString("export.email.body", comment: "")
                            .replacingOccurrences(of: "{quarter}", with: currentQ),
                        attachmentURL: url
                    )
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInPrompt(
                    title: NSLocalizedString("export.signIn.title", comment: ""),
                    subtitle: NSLocalizedString("export.signIn.subtitle", comment: "")
                )
            }
            .sheet(isPresented: $showWarningReview) {
                WarningReviewSheet(
                    title: warningReviewTitle,
                    expenses: warningReviewExpenses
                )
            }
        }
    }

    // MARK: - Sign in required

    private var signInRequired: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
                .accessibilityHidden(true)
            Text(NSLocalizedString("export.signIn.headline", comment: ""))
                .font(.title2).fontWeight(.bold)
            Text(NSLocalizedString("export.signIn.body", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showSignIn = true
            } label: {
                Text(NSLocalizedString("export.signIn.title", comment: ""))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Preview phase

    private var previewContent: some View {
        Form {
            Section(NSLocalizedString("export.period", comment: "")) {
                Picker(NSLocalizedString("export.quarter", comment: ""), selection: $selectedQuarter) {
                    ForEach(quarters, id: \.self) { q in
                        Text(q).tag(q)
                    }
                }
            }

            let totals = store.totalsByCurrency(for: currentQ)

            if totals.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("export.no_expenses", comment: ""))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Summary per currency
                ForEach(totals) { t in
                    Section("\(NSLocalizedString("export.totals", comment: "")) — \(t.currency)") {
                        summaryRow(NSLocalizedString("export.invoices", comment: ""), "\(t.count)")
                        summaryRow(NSLocalizedString("export.subtotal", comment: ""),
                                   Formatters.money(t.subtotal, currency: t.currency))
                        summaryRow(NSLocalizedString("export.tax", comment: ""),
                                   Formatters.money(t.tax, currency: t.currency))
                        summaryRow(NSLocalizedString("export.total", comment: ""),
                                   Formatters.money(t.total, currency: t.currency))
                    }
                }

                // Warnings (tappable to review & fix)
                let warnings = structuredWarnings(for: currentQ)
                if !warnings.isEmpty {
                    Section(NSLocalizedString("export.warnings", comment: "")) {
                        ForEach(warnings) { w in
                            Button {
                                warningReviewTitle = w.label
                                warningReviewExpenses = w.expenses
                                showWarningReview = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text(w.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                // Accountant
                Section(NSLocalizedString("export.accountant", comment: "")) {
                    if let email = auth.accountantEmail, !email.isEmpty {
                        HStack {
                            Image(systemName: "person.text.rectangle.fill")
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading) {
                                if let name = auth.accountantName, !name.isEmpty {
                                    Text(name).fontWeight(.medium)
                                }
                                Text(email).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(NSLocalizedString("common.edit", comment: "")) {
                                showAccountantPrompt = true
                            }
                            .font(.caption)
                        }
                    } else {
                        Button {
                            showAccountantPrompt = true
                        } label: {
                            Label(NSLocalizedString("accountant.add", comment: ""),
                                  systemImage: "plus.circle")
                        }
                    }
                }

                // Generate button
                Section {
                    Button {
                        Task { await generateExport() }
                    } label: {
                        HStack {
                            Spacer()
                            Label(NSLocalizedString("export.generate", comment: ""),
                                  systemImage: "square.and.arrow.up.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }

                Section {
                    Text(NSLocalizedString("export.description", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Generating phase

    private var generatingContent: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(NSLocalizedString("export.generating", comment: ""))
                .font(.headline)
            if let progress = exportJob?.progress {
                ProgressView(value: Double(progress), total: 100)
                    .frame(maxWidth: 200)
                Text("\(progress)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Success phase

    private var successContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: phase == .success)
                .accessibilityHidden(true)

            Text(NSLocalizedString("export.success.title", comment: ""))
                .font(.title2)
                .fontWeight(.bold)

            if let job = exportJob, let stats = job.stats?.byCurrency {
                let total = stats.values.reduce(0) { $0 + $1.count }
                Text(NSLocalizedString("export.success.subtitle", comment: "")
                    .replacingOccurrences(of: "{count}", with: "\(total)")
                    .replacingOccurrences(of: "{quarter}", with: currentQ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Share options
            VStack(spacing: 12) {
                // Server-side email via InvoScanAI (works without Mail.app)
                if let email = auth.accountantEmail, !email.isEmpty {
                    shareButton(
                        emailSent
                            ? NSLocalizedString("export.share.email_sent", comment: "")
                            : (isSendingEmail
                                ? NSLocalizedString("export.share.sending", comment: "")
                                : NSLocalizedString("export.share.email", comment: "")
                                    .replacingOccurrences(of: "{name}", with: auth.accountantName ?? email)),
                        icon: emailSent ? "checkmark.circle.fill" : (isSendingEmail ? "hourglass" : "envelope.fill"),
                        color: emailSent ? .green : .blue
                    ) {
                        Task { await sendEmailToAccountant() }
                    }
                    .disabled(isSendingEmail || emailSent)
                }

                shareButton(
                    NSLocalizedString("export.share.share", comment: ""),
                    icon: "square.and.arrow.up",
                    color: .indigo
                ) {
                    showShareSheet = true
                }

                shareButton(
                    showLinkCopied
                        ? NSLocalizedString("export.share.link_copied", comment: "")
                        : NSLocalizedString("export.share.copy_link", comment: ""),
                    icon: showLinkCopied ? "checkmark" : "link",
                    color: showLinkCopied ? .green : .orange
                ) {
                    Task { await copyShareLink() }
                }

                Button {
                    phase = .preview
                    exportJob = nil
                    shareURL = nil
                    shareLink = nil
                } label: {
                    Text(NSLocalizedString("export.done", comment: ""))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Actions

    private func generateExport() async {
        isLoading = true
        errorMessage = nil
        phase = .generating

        do {
            let job = try await APIClient.shared.createExportJob(quarter: currentQ)
            exportJob = job

            if job.isReady {
                // No expenses or instant completion
                await downloadAndFinish(jobId: job.id)
                return
            }

            // Poll for completion
            for _ in 0..<60 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                let updated = try await APIClient.shared.getExportJob(id: job.id)
                exportJob = updated
                if updated.isReady {
                    await downloadAndFinish(jobId: updated.id)
                    return
                }
                if updated.isFailed {
                    throw NSError(domain: "export", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                }
            }
            throw NSError(domain: "export", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Export timed out"])
        } catch {
            errorMessage = error.localizedDescription
            phase = .preview
        }
        isLoading = false
    }

    private func downloadAndFinish(jobId: String) async {
        do {
            let url = try await APIClient.shared.downloadExportJob(id: jobId)
            shareURL = url
            phase = .success
        } catch {
            errorMessage = error.localizedDescription
            phase = .preview
        }
        isLoading = false
    }

    private func copyShareLink() async {
        guard let job = exportJob else { return }
        do {
            if shareLink == nil {
                let response = try await APIClient.shared.createShareLink(exportId: job.id)
                shareLink = response.url
            }
            UIPasteboard.general.string = shareLink
            showLinkCopied = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showLinkCopied = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendEmailToAccountant() async {
        guard let job = exportJob else { return }
        isSendingEmail = true
        do {
            _ = try await APIClient.shared.sendExportEmail(exportId: job.id)
            emailSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingEmail = false
    }

    // MARK: - Structured warnings

    struct ExportWarningItem: Identifiable {
        let id: String
        let label: String
        let expenses: [Expense]
    }

    private func structuredWarnings(for quarter: String) -> [ExportWarningItem] {
        let exps = store.expenses(in: quarter)
        var warnings: [ExportWarningItem] = []
        let noCif = exps.filter { ($0.cif ?? "").isEmpty }
        if !noCif.isEmpty {
            warnings.append(ExportWarningItem(
                id: "no_tax_id",
                label: String(format: NSLocalizedString("export.warning.no_tax_id", comment: ""), noCif.count),
                expenses: noCif))
        }
        let pending = exps.filter { $0.status == .pending }
        if !pending.isEmpty {
            warnings.append(ExportWarningItem(
                id: "pending",
                label: String(format: NSLocalizedString("export.warning.pending", comment: ""), pending.count),
                expenses: pending))
        }
        let uncategorized = exps.filter { $0.category == .otros }
        if !uncategorized.isEmpty {
            warnings.append(ExportWarningItem(
                id: "uncategorized",
                label: String(format: NSLocalizedString("export.warning.uncategorized", comment: ""), uncategorized.count),
                expenses: uncategorized))
        }
        return warnings
    }

    // MARK: - Helpers

    @ViewBuilder
    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }

    @ViewBuilder
    private func shareButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .fontWeight(.semibold)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - WarningReviewSheet

struct WarningReviewSheet: View {
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    let expenses: [Expense]
    @State private var currentIndex: Int = 0
    @State private var editedExpense: Expense?
    @State private var attachmentData: Data?
    @State private var attachmentType: String?
    @State private var isLoadingAttachment = false
    @State private var showAttachment = false
    @State private var attachmentError: String?

    private var current: Expense? {
        guard currentIndex >= 0, currentIndex < expenses.count else { return nil }
        return editedExpense ?? expenses[currentIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Counter
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentIndex + 1) / \(expenses.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if let expense = current {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Vendor header card
                            HStack {
                                Image(systemName: expense.source.icon)
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.vendor)
                                        .font(.headline)
                                    Text(Formatters.shortDate.string(from: expense.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Formatters.money(expense.total, currency: expense.currency))
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            // Attachment preview
                            if expense.hasRemoteAttachment {
                                if showAttachment, let data = attachmentData, let type = attachmentType {
                                    AttachmentPreview(data: data, contentType: type)
                                        .frame(maxHeight: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else if let attachmentError {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.red)
                                        Text(attachmentError)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else {
                                    Button {
                                        Task { await loadAttachment(for: expense) }
                                    } label: {
                                        HStack(spacing: 10) {
                                            if isLoadingAttachment {
                                                ProgressView().scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "doc.fill")
                                                    .foregroundStyle(.indigo)
                                            }
                                            Text(NSLocalizedString("export.warning_review.view_file", comment: "View file"))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.indigo)
                                            Spacer()
                                            Image(systemName: "eye")
                                                .foregroundStyle(.indigo.opacity(0.6))
                                        }
                                        .padding(14)
                                        .background(Color.indigo.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .disabled(isLoadingAttachment)
                                }
                            }

                            // Editable fields card
                            editableFields(for: expense)

                            // Invoice number (read-only context)
                            if let inv = expense.invoiceNumber, !inv.isEmpty {
                                HStack {
                                    Text(NSLocalizedString("detail.invoice", comment: ""))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(inv)
                                }
                                .padding(16)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }

                    Spacer()

                    // Navigation bar
                    HStack(spacing: 16) {
                        Button {
                            saveAndMove(delta: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 52, height: 52)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(NSLocalizedString("a11y.previous_item", comment: ""))
                        .disabled(currentIndex == 0)

                        Button {
                            saveCurrent()
                            dismiss()
                        } label: {
                            Text(NSLocalizedString("export.warning_review.done", comment: "Done"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.indigo)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            saveAndMove(delta: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 52, height: 52)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(NSLocalizedString("a11y.next_item", comment: ""))
                        .disabled(currentIndex >= expenses.count - 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle(NSLocalizedString("export.warning_review.title", comment: "Review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", comment: "")) {
                        saveCurrent()
                        dismiss()
                    }
                }
            }
            .onAppear {
                editedExpense = expenses.first
            }
        }
    }

    // MARK: - Editable fields

    @ViewBuilder
    private func editableFields(for expense: Expense) -> some View {
        VStack(spacing: 12) {
            // Tax ID (CIF/NIF)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("detail.tax_id", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(NSLocalizedString("detail.tax_id", comment: ""), text: Binding(
                    get: { editedExpense?.cif ?? "" },
                    set: { editedExpense?.cif = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((editedExpense?.cif ?? "").isEmpty ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }

            // Category
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("detail.category", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(NSLocalizedString("detail.category", comment: ""), selection: Binding(
                    get: { editedExpense?.category ?? .otros },
                    set: { editedExpense?.category = $0 }
                )) {
                    ForEach(TaxCategory.allCases, id: \.self) { c in
                        Text(c.localizedName).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Status
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("detail.status", comment: "Status"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    statusButton(.confirmed, icon: "checkmark.circle.fill", color: .green)
                    statusButton(.pending, icon: "clock.fill", color: .orange)
                    statusButton(.rejected, icon: "xmark.circle.fill", color: .red)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func statusButton(_ status: ExpenseStatus, icon: String, color: Color) -> some View {
        let isSelected = editedExpense?.status == status
        Button {
            editedExpense?.status = status
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(status.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
        }
    }

    // MARK: - Attachment

    private func loadAttachment(for expense: Expense) async {
        isLoadingAttachment = true
        attachmentError = nil
        defer { isLoadingAttachment = false }
        do {
            let (data, contentType) = try await APIClient.shared.downloadAttachment(expenseId: expense.id.uuidString)
            attachmentData = data
            attachmentType = contentType
            showAttachment = true
        } catch let APIError.http(code, _) where code == 404 {
            attachmentError = NSLocalizedString("detail.attachment.not_found", comment: "")
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    private func clearAttachment() {
        attachmentData = nil
        attachmentType = nil
        attachmentError = nil
        showAttachment = false
    }

    // MARK: - Save & navigate

    private func saveCurrent() {
        guard let edited = editedExpense else { return }
        store.update(edited)
        var body: [String: Any] = [:]
        body["cif"] = edited.cif ?? ""
        body["category"] = edited.category.rawValue
        body["status"] = edited.status.rawValue
        Task { try? await APIClient.shared.patchExpense(id: edited.id.uuidString, body: body) }
    }

    private func saveAndMove(delta: Int) {
        saveCurrent()
        clearAttachment()
        let next = currentIndex + delta
        guard next >= 0, next < expenses.count else { return }
        currentIndex = next
        editedExpense = expenses[next]
    }
}

// MARK: - AttachmentPreview

private struct AttachmentPreview: View {
    let data: Data
    let contentType: String

    var body: some View {
        if contentType.contains("pdf") {
            PDFPreview(data: data)
        } else if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Label(NSLocalizedString("export.warning_review.unsupported", comment: "Cannot preview"), systemImage: "doc.questionmark")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - MailComposer

struct MailComposer: UIViewControllerRepresentable {
    let toRecipients: [String]
    let subject: String
    let body: String
    let attachmentURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mc = MFMailComposeViewController()
        mc.mailComposeDelegate = context.coordinator
        mc.setToRecipients(toRecipients)
        mc.setSubject(subject)
        mc.setMessageBody(body, isHTML: false)
        if let url = attachmentURL, let data = try? Data(contentsOf: url) {
            mc.addAttachmentData(data, mimeType: "application/zip", fileName: url.lastPathComponent)
        }
        return mc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
