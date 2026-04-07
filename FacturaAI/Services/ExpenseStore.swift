import Foundation
import Combine

@MainActor
final class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?

    init() {
        self.expenses = MockData.sampleExpenses()
    }

    // MARK: - Sync simulation

    func syncGmail() async {
        isSyncing = true
        defer { isSyncing = false }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        // Simulate finding 1-2 new invoices
        let newOnes = MockData.sampleExpenses().prefix(1).map { e -> Expense in
            var copy = e
            copy.id = UUID()
            copy.date = Date()
            copy.status = .pending
            copy.invoiceNumber = "NEW-\(Int.random(in: 1000...9999))"
            return copy
        }
        expenses.insert(contentsOf: newOnes, at: 0)
        lastSyncDate = Date()
    }

    // MARK: - CRUD

    func update(_ expense: Expense) {
        if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[idx] = expense
        }
    }

    func confirm(_ expense: Expense) {
        var copy = expense
        copy.status = .confirmed
        update(copy)
    }

    func reject(_ expense: Expense) {
        var copy = expense
        copy.status = .rejected
        update(copy)
    }

    func delete(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
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
