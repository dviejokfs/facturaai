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
                    title: "Sign in to export",
                    subtitle: "Create an account to export your expenses as CSV, Excel, or send them directly to your accountant."
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
            Text("Export your expenses")
                .font(.title2).fontWeight(.bold)
            Text("Sign in to export CSV, Excel, and original invoices in a ZIP — ready to send to your accountant.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showSignIn = true
            } label: {
                Text("Sign in to export")
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

                // Warnings
                let warnings = localWarnings(for: currentQ)
                if !warnings.isEmpty {
                    Section(NSLocalizedString("export.warnings", comment: "")) {
                        ForEach(warnings, id: \.self) { w in
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text(w)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                if let email = auth.accountantEmail, !email.isEmpty, MFMailComposeViewController.canSendMail() {
                    shareButton(
                        NSLocalizedString("export.share.email", comment: "")
                            .replacingOccurrences(of: "{name}", with: auth.accountantName ?? email),
                        icon: "envelope.fill",
                        color: .blue
                    ) {
                        showMailComposer = true
                    }
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

    // MARK: - Local warnings

    private func localWarnings(for quarter: String) -> [String] {
        let exps = store.expenses(in: quarter)
        var warnings: [String] = []
        let noCif = exps.filter { ($0.cif ?? "").isEmpty }.count
        if noCif > 0 { warnings.append("\(noCif) expenses without supplier tax ID") }
        let pending = exps.filter { $0.status == .pending }.count
        if pending > 0 { warnings.append("\(pending) expenses still pending") }
        let uncategorized = exps.filter { $0.category == .otros }.count
        if uncategorized > 0 { warnings.append("\(uncategorized) uncategorized expenses") }
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
