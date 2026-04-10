import Foundation
import Combine

@MainActor
final class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var companies: [RemoteCompany] = []
    @Published var activeCompanyId: UUID?
    @Published var isSyncing: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?
    @Published var lastError: String?
    @Published var syncProgress: GmailSyncProgress?

    struct GmailSyncProgress {
        var status: String
        var messagesProcessed: Int
        var totalMessages: Int
        var invoicesFound: Int

        var fraction: Double {
            guard totalMessages > 0 else { return 0 }
            return Double(messagesProcessed) / Double(totalMessages)
        }

        var label: String {
            if totalMessages == 0 {
                return NSLocalizedString("dashboard.sync.scanning", comment: "")
            }
            return String(format: NSLocalizedString("dashboard.sync.progress", comment: ""), messagesProcessed, totalMessages, invoicesFound)
        }
    }

    init() {}

    // MARK: - Companies

    func loadCompanies() async {
        guard Keychain.loadToken() != nil else { return }
        do {
            self.companies = try await APIClient.shared.listCompanies()
        } catch {
            print("[ExpenseStore] loadCompanies error: \(error)")
        }
    }

    // MARK: - Remote sync

    func reload() async {
        guard Keychain.loadToken() != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await APIClient.shared.listExpenses()
            let remoteExpenses = remote.map { $0.toDomain() }
            // Merge: keep locally scanned expenses that aren't on the server yet
            let remoteIDs = Set(remoteExpenses.map { $0.id })
            let localOnly = expenses.filter { !remoteIDs.contains($0.id) }
            self.expenses = localOnly + remoteExpenses
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    func syncGmail() async {
        isSyncing = true
        lastError = nil
        syncProgress = GmailSyncProgress(status: "queued", messagesProcessed: 0, totalMessages: 0, invoicesFound: 0)
        do {
            let sync = try await APIClient.shared.triggerGmailSync()
            await pollSync(id: sync.id)
        } catch {
            isSyncing = false
            syncProgress = GmailSyncProgress(status: "failed", messagesProcessed: 0, totalMessages: 0, invoicesFound: 0)
            lastError = error.localizedDescription
            print("[syncGmail] request error: \(error)")
        }
    }

    /// Check for any active sync on the backend (e.g. after app returns to foreground).
    /// If one is running, resume polling. If one just completed, update state.
    func checkActiveSync() async {
        guard Keychain.loadToken() != nil else { return }
        guard !isSyncing else { return } // already polling
        do {
            guard let active = try await APIClient.shared.getActiveGmailSync() else { return }

            if active.status == "queued" || active.status == "running" {
                // Resume polling the in-progress sync
                isSyncing = true
                lastError = nil
                syncProgress = GmailSyncProgress(
                    status: active.status,
                    messagesProcessed: active.messagesProcessed ?? 0,
                    totalMessages: active.totalMessages ?? 0,
                    invoicesFound: active.invoicesFound ?? 0
                )
                await pollSync(id: active.id)
            } else if active.status == "completed" {
                // Sync finished while we were away — refresh expenses
                syncProgress = GmailSyncProgress(
                    status: "completed",
                    messagesProcessed: active.messagesProcessed ?? 0,
                    totalMessages: active.totalMessages ?? 0,
                    invoicesFound: active.invoicesFound ?? 0
                )
                await reload()
            }
        } catch {
            print("[checkActiveSync] error: \(error)")
        }
    }

    /// Shared polling loop for a given sync ID.
    private func pollSync(id: String) async {
        do {
            for i in 0..<120 {
                let interval: UInt64 = i < 5 ? 1_000_000_000 : 2_000_000_000 // 1s then 2s
                try? await Task.sleep(nanoseconds: interval)
                let status = try await APIClient.shared.getGmailSync(id: id)
                syncProgress = GmailSyncProgress(
                    status: status.status,
                    messagesProcessed: status.messagesProcessed ?? 0,
                    totalMessages: status.totalMessages ?? 0,
                    invoicesFound: status.invoicesFound ?? 0
                )
                if status.status == "failed" {
                    isSyncing = false
                    lastError = status.error ?? "Unknown error"
                    print("[syncGmail] backend reported failure: \(status.error ?? "no error message")")
                    return
                }
                if status.isComplete { break }
            }
            isSyncing = false
            await reload()
            lastSyncDate = Date()
        } catch {
            isSyncing = false
            syncProgress = GmailSyncProgress(status: "failed", messagesProcessed: 0, totalMessages: 0, invoicesFound: 0)
            lastError = error.localizedDescription
            print("[syncGmail] poll error: \(error)")
        }
    }

    func clearSyncProgress() {
        syncProgress = nil
    }

    // MARK: - CRUD (optimistic local + remote PATCH)

    func update(_ expense: Expense) {
        if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[idx] = expense
        }
    }

    func confirm(_ expense: Expense) {
        var copy = expense
        copy.status = .confirmed
        update(copy)
        Task { try? await APIClient.shared.patchExpense(id: expense.id.uuidString, body: ["status": "confirmed"]) }
    }

    func reject(_ expense: Expense) {
        var copy = expense
        copy.status = .rejected
        update(copy)
        Task { try? await APIClient.shared.patchExpense(id: expense.id.uuidString, body: ["status": "rejected"]) }
    }

    func delete(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        Task { try? await APIClient.shared.deleteExpense(id: expense.id.uuidString) }
    }

    func add(_ expense: Expense) {
        expenses.insert(expense, at: 0)
    }

    /// Extract data from a receipt without saving. Returns the expense for user review.
    func extractReceipt(data: Data, filename: String) async throws -> Expense {
        let mime = Self.mimeType(for: filename)
        if Keychain.loadToken() != nil {
            let remote = try await APIClient.shared.uploadReceipt(imageData: data, filename: filename, mimeType: mime)
            return remote.toDomain()
        } else {
            let extracted = try await APIClient.shared.extractOnly(imageData: data, filename: filename, mimeType: mime)
            return extracted.toDomain()
        }
    }

    /// Upload a receipt (image or PDF) and get back the AI-extracted expense.
    /// When not authenticated, uses the public extract endpoint and stores locally only.
    /// When authenticated, uploads to the server and persists remotely.
    func uploadReceipt(data: Data, filename: String) async throws -> Expense {
        let expense = try await extractReceipt(data: data, filename: filename)
        expenses.insert(expense, at: 0)
        return expense
    }

    private static func mimeType(for filename: String) -> String {
        let lower = filename.lowercased()
        if lower.hasSuffix(".pdf") { return "application/pdf" }
        if lower.hasSuffix(".png") { return "image/png" }
        if lower.hasSuffix(".heic") { return "image/heic" }
        return "image/jpeg"
    }

    /// Upload a file received via the iOS Share Sheet.
    func uploadSharedFile(data: Data, filename: String) async {
        guard Keychain.loadToken() != nil else { return }
        do {
            _ = try await uploadReceipt(data: data, filename: filename)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Filtering & aggregates

    func expenses(in quarter: String) -> [Expense] {
        expenses.filter { $0.quarter == quarter && $0.status != .rejected }
    }

    func expenses(in quarter: String, type: TransactionType) -> [Expense] {
        expenses(in: quarter).filter { $0.type == type }
    }

    func incomeTotal(for quarter: String) -> Decimal {
        expenses(in: quarter, type: .income).reduce(0) { $0 + $1.total }
    }

    func expenseTotal(for quarter: String) -> Decimal {
        expenses(in: quarter, type: .expense).reduce(0) { $0 + $1.total }
    }

    func netResult(for quarter: String) -> Decimal {
        incomeTotal(for: quarter) - expenseTotal(for: quarter)
    }

    func currentQuarter() -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        let q = ((comps.month ?? 1) - 1) / 3 + 1
        return "\(comps.year ?? 0)-Q\(q)"
    }

    func totalIVA(for quarter: String) -> Decimal {
        expenses(in: quarter).reduce(0) { $0 + $1.ivaAmount }
    }

    func totalSubtotal(for quarter: String) -> Decimal {
        expenses(in: quarter).reduce(0) { $0 + $1.subtotal }
    }

    func totalAmount(for quarter: String) -> Decimal {
        expenses(in: quarter).reduce(0) { $0 + $1.total }
    }

    func byCategory(for quarter: String) -> [(TaxCategory, Decimal)] {
        let grouped = Dictionary(grouping: expenses(in: quarter), by: { $0.category })
        return grouped
            .map { ($0.key, $0.value.reduce(Decimal(0)) { $0 + $1.total }) }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: - Multi-currency aggregates (NEVER converted)

    struct CurrencyTotals: Identifiable {
        let currency: String
        let count: Int
        let subtotal: Decimal
        let tax: Decimal
        let total: Decimal
        var id: String { currency }
    }

    func totalsByCurrency(for quarter: String) -> [CurrencyTotals] {
        let grouped = Dictionary(grouping: expenses(in: quarter), by: { $0.currency })
        return grouped.map { ccy, list in
            CurrencyTotals(
                currency: ccy,
                count: list.count,
                subtotal: list.reduce(0) { $0 + $1.subtotal },
                tax: list.reduce(0) { $0 + $1.ivaAmount },
                total: list.reduce(0) { $0 + $1.total }
            )
        }
        .sorted { $0.total > $1.total }
    }
}
