import Foundation
import Combine

@MainActor
final class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isSyncing: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?
    @Published var lastError: String?

    /// When true, backend is unreachable or user not signed in → use in-memory mock data.
    var useMockFallback = true

    init() {
        self.expenses = MockData.sampleExpenses()
    }

    // MARK: - Remote sync

    func reload() async {
        guard Keychain.loadToken() != nil else {
            if useMockFallback { expenses = MockData.sampleExpenses() }
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await APIClient.shared.listExpenses()
            self.expenses = remote.map { $0.toDomain() }
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
            if useMockFallback && expenses.isEmpty {
                expenses = MockData.sampleExpenses()
            }
        }
    }

    func syncGmail() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let sync = try await APIClient.shared.triggerGmailSync()
            // Poll a few times for completion
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let status = try await APIClient.shared.getGmailSync(id: sync.id)
                if status.status == "completed" || status.status == "failed" { break }
            }
            await reload()
            lastSyncDate = Date()
        } catch {
            lastError = error.localizedDescription
            // Fallback: simulate one new mock item so the UI demos something
            if useMockFallback {
                var copy = MockData.sampleExpenses()[0]
                copy.id = UUID()
                copy.date = Date()
                copy.status = .pending
                copy.invoiceNumber = "NEW-\(Int.random(in: 1000...9999))"
                expenses.insert(copy, at: 0)
                lastSyncDate = Date()
            }
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
}
