import Foundation
import Combine

@MainActor
final class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isSyncing: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?
    @Published var lastError: String?

    init() {}

    // MARK: - Remote sync

    func reload() async {
        guard Keychain.loadToken() != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await APIClient.shared.listExpenses()
            self.expenses = remote.map { $0.toDomain() }
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    func syncGmail() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let sync = try await APIClient.shared.triggerGmailSync()
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let status = try await APIClient.shared.getGmailSync(id: sync.id)
                if status.status == "completed" || status.status == "failed" { break }
            }
            await reload()
            lastSyncDate = Date()
        } catch {
            lastError = error.localizedDescription
        }
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

    /// Upload a receipt (image or PDF) and get back the AI-extracted expense.
    func uploadReceipt(data: Data, filename: String) async throws -> Expense {
        let lower = filename.lowercased()
        let mime: String
        if lower.hasSuffix(".pdf") { mime = "application/pdf" }
        else if lower.hasSuffix(".png") { mime = "image/png" }
        else if lower.hasSuffix(".heic") { mime = "image/heic" }
        else { mime = "image/jpeg" }
        let remote = try await APIClient.shared.uploadReceipt(imageData: data, filename: filename, mimeType: mime)
        let expense = remote.toDomain()
        expenses.insert(expense, at: 0)
        return expense
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
