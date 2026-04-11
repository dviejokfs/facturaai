import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: ExpenseStore
    @EnvironmentObject var auth: AuthService
    var onScanTap: (() -> Void)? = nil
    @State private var selectedQuarter: String?
    @AppStorage("hasCompletedOnboardingChecklist") private var hasCompletedOnboardingChecklist = false
    @State private var showGmailSync = false
    @State private var showAccountantSetup = false

    /// All quarters that have expenses, sorted newest first.
    private var availableQuarters: [String] {
        let all = Set(store.expenses.map { $0.quarter })
        return all.sorted().reversed()
    }

    /// The active quarter: user-selected, or the most recent with data, or current calendar quarter.
    private var activeQuarter: String {
        if let sel = selectedQuarter, availableQuarters.contains(sel) { return sel }
        return availableQuarters.first ?? store.currentQuarter()
    }

    /// Show onboarding checklist when signed in but Gmail or accountant not yet set up
    private var shouldShowOnboardingChecklist: Bool {
        guard auth.isSignedIn, !hasCompletedOnboardingChecklist else { return false }
        let gmailDone = auth.gmailConnected
        let accountantDone = auth.accountantEmail != nil && !(auth.accountantEmail?.isEmpty ?? true)
        return !gmailDone || !accountantDone
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Onboarding checklist (after sign-up)
                    if shouldShowOnboardingChecklist {
                        OnboardingChecklistCard(
                            gmailDone: auth.gmailConnected,
                            accountantDone: auth.accountantEmail != nil && !(auth.accountantEmail?.isEmpty ?? true),
                            onGmail: { showGmailSync = true },
                            onAccountant: { showAccountantSetup = true },
                            onDismiss: { withAnimation { hasCompletedOnboardingChecklist = true } }
                        )
                    }

                    if store.expenses.isEmpty {
                        WelcomeHeader()
                        QuickActions(onScanTap: onScanTap)
                        if !shouldShowOnboardingChecklist {
                            GettingStartedChecklist()
                        }
                    } else {
                        let q = activeQuarter
                        let totals = store.totalsByCurrency(for: q)

                        // Quarter picker
                        if availableQuarters.count > 1 {
                            QuarterPicker(
                                quarters: availableQuarters,
                                selected: Binding(
                                    get: { activeQuarter },
                                    set: { selectedQuarter = $0 }
                                )
                            )
                        }

                        // Main totals per currency
                        if totals.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text(String(format: NSLocalizedString("dashboard.no_expenses_quarter", comment: ""), q))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                        } else {
                            ForEach(totals) { t in
                                SummaryCard(quarter: q, totals: t)
                            }
                        }

                        // Income vs Expense breakdown
                        IncomeExpenseCard(quarter: q)

                        // Pending review alert
                        let pendingCount = store.expenses.filter { $0.status == .pending }.count
                        if pendingCount > 0 {
                            PendingReviewCard(count: pendingCount)
                        }

                        // Key metrics row
                        KeyMetricsRow(quarter: q)

                        // Monthly spend chart
                        MonthlySpendChart()

                        // Top vendors
                        TopVendorsCard(quarter: q)

                        // Tax summary
                        TaxSummaryCard(quarter: q)

                        // Category breakdown
                        CategoryBreakdown(items: store.byCategory(for: q))

                        // Gmail sync
                        SyncCard()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showGmailSync) {
                GmailSyncView()
            }
            .sheet(isPresented: $showAccountantSetup) {
                NavigationStack {
                    AccountantSettingsView()
                }
            }
        }
    }
}

// MARK: - Quarter Picker

private struct QuarterPicker: View {
    let quarters: [String]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quarters, id: \.self) { q in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selected = q }
                    } label: {
                        Text(q)
                            .font(.subheadline)
                            .fontWeight(q == selected ? .bold : .medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                q == selected
                                    ? AnyShapeStyle(Color.indigo)
                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                            )
                            .foregroundStyle(q == selected ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

private struct WelcomeHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.15), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
            }

            Text(NSLocalizedString("dashboard.welcome.title", comment: ""))
                .font(.title2.bold())

            Text(NSLocalizedString("dashboard.welcome.subtitle", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }
}

private struct QuickActions: View {
    @EnvironmentObject var auth: AuthService
    var onScanTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                QuickActionButton(
                    icon: "camera.fill",
                    title: NSLocalizedString("dashboard.quick.scan", comment: ""),
                    subtitle: NSLocalizedString("dashboard.quick.scan.subtitle", comment: ""),
                    color: .indigo,
                    action: onScanTap
                )
                QuickActionButton(
                    icon: "doc.fill",
                    title: NSLocalizedString("dashboard.quick.upload", comment: ""),
                    subtitle: NSLocalizedString("dashboard.quick.upload.subtitle", comment: ""),
                    color: .blue,
                    action: onScanTap
                )
            }
            HStack(spacing: 10) {
                QuickActionButton(
                    icon: "envelope.fill",
                    title: NSLocalizedString("dashboard.quick.gmail", comment: ""),
                    subtitle: NSLocalizedString("dashboard.quick.gmail.subtitle", comment: ""),
                    color: .purple,
                    action: nil
                )
                QuickActionButton(
                    icon: "square.and.pencil",
                    title: NSLocalizedString("dashboard.quick.manual", comment: ""),
                    subtitle: NSLocalizedString("dashboard.quick.manual.subtitle", comment: ""),
                    color: .teal,
                    action: onScanTap
                )
            }
        }
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        }
    }
}

private struct OnboardingChecklistCard: View {
    let gmailDone: Bool
    let accountantDone: Bool
    let onGmail: () -> Void
    let onAccountant: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundStyle(.indigo)
                    Text(NSLocalizedString("onboarding.checklist.title", comment: ""))
                        .font(.headline)
                }
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Text(NSLocalizedString("onboarding.checklist.subtitle", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onGmail) {
                HStack(spacing: 12) {
                    Image(systemName: gmailDone ? "checkmark.circle.fill" : "envelope.fill")
                        .font(.title3)
                        .foregroundStyle(gmailDone ? .green : .red)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("onboarding.checklist.gmail", comment: ""))
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(gmailDone ? .secondary : .primary)
                            .strikethrough(gmailDone)
                        Text(NSLocalizedString("onboarding.checklist.gmail.sub", comment: ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !gmailDone {
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(gmailDone)

            Button(action: onAccountant) {
                HStack(spacing: 12) {
                    Image(systemName: accountantDone ? "checkmark.circle.fill" : "person.text.rectangle.fill")
                        .font(.title3)
                        .foregroundStyle(accountantDone ? .green : .teal)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("onboarding.checklist.accountant", comment: ""))
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(accountantDone ? .secondary : .primary)
                            .strikethrough(accountantDone)
                        Text(NSLocalizedString("onboarding.checklist.accountant.sub", comment: ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !accountantDone {
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(accountantDone)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct GettingStartedChecklist: View {
    @EnvironmentObject var store: ExpenseStore
    @EnvironmentObject var auth: AuthService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.clipboard.fill")
                    .foregroundStyle(.indigo)
                Text(NSLocalizedString("dashboard.checklist.title", comment: ""))
                    .font(.headline)
            }

            ChecklistItem(
                title: NSLocalizedString("dashboard.checklist.account", comment: ""),
                subtitle: NSLocalizedString("dashboard.checklist.account.sub", comment: ""),
                done: auth.isSignedIn,
                icon: "person.crop.circle.fill"
            )

            ChecklistItem(
                title: NSLocalizedString("dashboard.checklist.scan", comment: ""),
                subtitle: NSLocalizedString("dashboard.checklist.scan.sub", comment: ""),
                done: !store.expenses.isEmpty,
                icon: "doc.viewfinder.fill"
            )

            ChecklistItem(
                title: NSLocalizedString("dashboard.checklist.gmail", comment: ""),
                subtitle: NSLocalizedString("dashboard.checklist.gmail.sub", comment: ""),
                done: auth.gmailConnected,
                icon: "envelope.fill"
            )

            ChecklistItem(
                title: NSLocalizedString("dashboard.checklist.accountant", comment: ""),
                subtitle: NSLocalizedString("dashboard.checklist.accountant.sub", comment: ""),
                done: auth.accountantEmail != nil && !(auth.accountantEmail?.isEmpty ?? true),
                icon: "person.text.rectangle.fill"
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct ChecklistItem: View {
    let title: String
    let subtitle: String
    let done: Bool
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .font(.title3)
                .foregroundStyle(done ? .green : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(done ? .secondary : .primary)
                    .strikethrough(done)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Tab switching notification

extension Notification.Name {
    static let switchToTab = Notification.Name("switchToTab")
    static let scanAnother = Notification.Name("scanAnother")
    static let upgradeNeeded = Notification.Name("upgradeNeeded")
    static let shouldRequestPushPermission = Notification.Name("shouldRequestPushPermission")
    static let navigateToExpense = Notification.Name("navigateToExpense")
}

// MARK: - Key Metrics

private struct KeyMetricsRow: View {
    @EnvironmentObject var store: ExpenseStore
    let quarter: String

    var body: some View {
        let qExpenses = store.expenses(in: quarter)
        let confirmed = qExpenses.filter { $0.status == .confirmed }.count
        let total = qExpenses.count
        let avgExpense: Decimal = total > 0 ? qExpenses.reduce(0) { $0 + $1.total } / Decimal(total) : 0
        let currency = store.totalsByCurrency(for: quarter).first?.currency ?? "EUR"

        HStack(spacing: 10) {
            MetricTile(
                icon: "doc.text.fill",
                value: "\(total)",
                label: NSLocalizedString("dashboard.metrics.invoices", comment: ""),
                color: .indigo
            )
            MetricTile(
                icon: "checkmark.circle.fill",
                value: "\(confirmed)",
                label: NSLocalizedString("dashboard.metrics.confirmed", comment: ""),
                color: .green
            )
            MetricTile(
                icon: "chart.line.uptrend.xyaxis",
                value: Formatters.money(avgExpense, currency: currency),
                label: NSLocalizedString("dashboard.metrics.avg", comment: ""),
                color: .blue
            )
        }
    }
}

private struct MetricTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.body.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Monthly Spend Chart

private struct MonthlySpendChart: View {
    @EnvironmentObject var store: ExpenseStore

    var body: some View {
        let months = last6Months()
        let currency = store.totalsByCurrency(for: store.currentQuarter()).first?.currency ?? "EUR"
        let maxVal = months.map(\.total).max() ?? 1

        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("dashboard.monthly.title", comment: ""))
                .font(.headline)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(months, id: \.label) { m in
                    VStack(spacing: 4) {
                        if m.total > 0 {
                            Text(Formatters.money(m.total, currency: currency))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.indigo, .purple.opacity(0.7)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: max(4, CGFloat(truncating: (m.total / maxVal * 100) as NSDecimalNumber)))

                        Text(m.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private struct MonthData {
        let label: String
        let total: Decimal
    }

    private func last6Months() -> [MonthData] {
        let cal = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"

        return (0..<6).reversed().map { offset in
            let date = cal.date(byAdding: .month, value: -offset, to: now)!
            let comps = cal.dateComponents([.year, .month], from: date)
            let total = store.expenses
                .filter { $0.status != .rejected }
                .filter {
                    let ec = cal.dateComponents([.year, .month], from: $0.date)
                    return ec.year == comps.year && ec.month == comps.month
                }
                .reduce(Decimal(0)) { $0 + $1.total }
            return MonthData(label: fmt.string(from: date), total: total)
        }
    }
}

// MARK: - Top Vendors

private struct TopVendorsCard: View {
    @EnvironmentObject var store: ExpenseStore
    let quarter: String

    var body: some View {
        let vendors = topVendors()
        let currency = store.totalsByCurrency(for: quarter).first?.currency ?? "EUR"

        if !vendors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("dashboard.vendors.title", comment: ""))
                    .font(.headline)

                ForEach(Array(vendors.enumerated()), id: \.element.name) { idx, vendor in
                    HStack(spacing: 12) {
                        Text("\(idx + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.indigo.opacity(1.0 - Double(idx) * 0.2)))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(vendor.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(String(format: NSLocalizedString("dashboard.vendors.invoice_count", comment: ""), vendor.count))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(Formatters.money(vendor.total, currency: currency))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        }
    }

    private struct VendorSummary {
        let name: String
        let total: Decimal
        let count: Int
    }

    private func topVendors() -> [VendorSummary] {
        let qExpenses = store.expenses(in: quarter)
        let grouped = Dictionary(grouping: qExpenses, by: { $0.vendor })
        return grouped
            .map { VendorSummary(name: $0.key, total: $0.value.reduce(0) { $0 + $1.total }, count: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Tax Summary

private struct TaxSummaryCard: View {
    @EnvironmentObject var store: ExpenseStore
    let quarter: String

    var body: some View {
        let qExpenses = store.expenses(in: quarter)
        let currency = store.totalsByCurrency(for: quarter).first?.currency ?? "EUR"
        let totalTax = qExpenses.reduce(Decimal(0)) { $0 + $1.ivaAmount }
        let totalWithholding = qExpenses.reduce(Decimal(0)) { $0 + $1.irpfAmount }
        let totalDeductible = qExpenses.filter { $0.status == .confirmed }.reduce(Decimal(0)) { $0 + $1.subtotal }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(.teal)
                Text(NSLocalizedString("dashboard.tax.title", comment: ""))
                    .font(.headline)
            }

            HStack(spacing: 0) {
                TaxItem(label: NSLocalizedString("dashboard.tax.deductible", comment: ""), value: Formatters.money(totalDeductible, currency: currency), color: .green)
                TaxItem(label: NSLocalizedString("dashboard.tax.vat", comment: ""), value: Formatters.money(totalTax, currency: currency), color: .blue)
                if totalWithholding > 0 {
                    TaxItem(label: NSLocalizedString("dashboard.tax.withholding", comment: ""), value: Formatters.money(totalWithholding, currency: currency), color: .orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct TaxItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Filled State Cards

private struct SummaryCard: View {
    let quarter: String
    let totals: ExpenseStore.CurrencyTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: NSLocalizedString("dashboard.summary.quarter", comment: ""), totals.currency))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(quarter).font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.15))
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
            }
            Text(Formatters.money(totals.total, currency: totals.currency))
                .font(.largeTitle.bold())
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("dashboard.summary.subtotal", comment: "")).font(.caption).foregroundStyle(.secondary)
                    Text(Formatters.money(totals.subtotal, currency: totals.currency))
                        .fontWeight(.semibold)
                }
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("dashboard.summary.tax", comment: "")).font(.caption).foregroundStyle(.secondary)
                    Text(Formatters.money(totals.tax, currency: totals.currency))
                        .fontWeight(.semibold).foregroundStyle(.green)
                }
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("dashboard.summary.invoices", comment: "")).font(.caption).foregroundStyle(.secondary)
                    Text("\(totals.count)").fontWeight(.semibold)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct IncomeExpenseCard: View {
    @EnvironmentObject var store: ExpenseStore
    let quarter: String

    var body: some View {
        let income = store.incomeTotal(for: quarter)
        let expense = store.expenseTotal(for: quarter)
        let net = store.netResult(for: quarter)
        let currency = store.totalsByCurrency(for: quarter).first?.currency ?? "EUR"

        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("dashboard.income_expense.title", comment: ""))
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(NSLocalizedString("transaction.income", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(Formatters.money(income, currency: currency))
                        .font(.body.bold())
                        .foregroundColor(.green)
                }
                .accessibilityElement(children: .combine)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(NSLocalizedString("transaction.expense", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(Formatters.money(expense, currency: currency))
                        .font(.body.bold())
                        .foregroundColor(.red)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(NSLocalizedString("dashboard.income_expense.net", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: net >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(Formatters.money(net, currency: currency))
                            .font(.body.bold())
                    }
                    .foregroundColor(net >= 0 ? .green : .red)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct SyncCard: View {
    @EnvironmentObject var store: ExpenseStore
    @EnvironmentObject var auth: AuthService
    @State private var showGmailSync = false

    var body: some View {
        Button {
            store.clearSyncProgress()
            showGmailSync = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "envelope.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                    .frame(width: 44, height: 44)
                    .background(Color.indigo.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("dashboard.sync.title", comment: ""))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(syncSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if store.isSyncing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        }
        .sheet(isPresented: $showGmailSync) {
            GmailSyncView()
        }
    }

    private var syncSubtitle: String {
        if store.isSyncing {
            return NSLocalizedString("gmailSync.syncing", comment: "")
        }
        if let d = store.lastSyncDate {
            return String(format: NSLocalizedString("dashboard.sync.last", comment: ""), Formatters.shortDate.string(from: d))
        }
        return auth.gmailConnected
            ? NSLocalizedString("gmailSync.idle.title", comment: "")
            : NSLocalizedString("gmailSync.connect", comment: "")
    }
}

private struct CategoryBreakdown: View {
    @EnvironmentObject var store: ExpenseStore
    let items: [(TaxCategory, Decimal)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("dashboard.category.title", comment: "")).font(.headline)
            if items.isEmpty {
                Text(NSLocalizedString("dashboard.category.empty", comment: "")).foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Circle().fill(color(for: item.0)).frame(width: 10, height: 10)
                        Text(item.0.localizedName).font(.subheadline)
                        Spacer()
                        Text(Formatters.money(item.1, currency: primaryCurrency))
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var primaryCurrency: String {
        store.totalsByCurrency(for: store.currentQuarter()).first?.currency ?? "EUR"
    }

    private func color(for c: TaxCategory) -> Color {
        let palette: [Color] = [.indigo, .purple, .blue, .teal, .green, .orange, .pink, .red, .yellow, .mint]
        let idx = abs(c.rawValue.hashValue) % palette.count
        return palette[idx]
    }
}

private struct PendingReviewCard: View {
    let count: Int
    @State private var showReview = false

    var body: some View {
        Button {
            showReview = true
        } label: {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(String(format: NSLocalizedString("dashboard.pending.title", comment: ""), count)).fontWeight(.semibold)
                    Text(NSLocalizedString("dashboard.pending.subtitle", comment: ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "hand.draw.fill")
                    .foregroundStyle(.orange.opacity(0.6))
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showReview) {
            SwipeReviewView()
        }
    }
}
