import SwiftUI

struct SwipeReviewView: View {
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0
    @State private var showDoneState = false

    private var pendingExpenses: [Expense] {
        store.expenses.filter { $0.status == .pending }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !showDoneState {
                        Text(String(format: NSLocalizedString("swipe.remaining", comment: ""), pendingExpenses.count))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if showDoneState || pendingExpenses.isEmpty {
                    // All reviewed
                    Spacer()
                    AllReviewedView()
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("common.done", comment: ""))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                } else {
                    // Swipe hint
                    HStack(spacing: 24) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.caption2)
                            Text(NSLocalizedString("swipe.hint.reject", comment: ""))
                                .font(.caption)
                        }
                        .foregroundStyle(.red.opacity(0.6))

                        Text(NSLocalizedString("swipe.hint.swipe", comment: ""))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Text(NSLocalizedString("swipe.hint.confirm", comment: ""))
                                .font(.caption)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green.opacity(0.6))
                    }
                    .padding(.top, 12)

                    // Card stack
                    ZStack {
                        // Show next card behind (peek)
                        if pendingExpenses.count > 1 {
                            ExpenseCard(expense: pendingExpenses[min(1, pendingExpenses.count - 1)])
                                .scaleEffect(0.95)
                                .offset(y: 8)
                                .opacity(0.6)
                        }

                        // Current card
                        if let expense = pendingExpenses.first {
                            ExpenseCard(expense: expense)
                                .offset(dragOffset)
                                .rotationEffect(.degrees(dragRotation))
                                .overlay(alignment: .top) {
                                    swipeLabel
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            dragOffset = value.translation
                                            dragRotation = Double(value.translation.width / 20)
                                        }
                                        .onEnded { value in
                                            let threshold: CGFloat = 120
                                            if value.translation.width > threshold {
                                                confirmCurrent(expense)
                                            } else if value.translation.width < -threshold {
                                                rejectCurrent(expense)
                                            } else {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                    dragOffset = .zero
                                                    dragRotation = 0
                                                }
                                            }
                                        }
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer()

                    // Action buttons
                    if let expense = pendingExpenses.first {
                        HStack(spacing: 32) {
                            // Reject
                            Button {
                                rejectCurrent(expense)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 64, height: 64)
                                    .background(Circle().fill(.red))
                                    .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                            }

                            // Edit (detail)
                            Button {
                                // Navigate to detail — handled via sheet
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(.orange))
                                    .shadow(color: .orange.opacity(0.3), radius: 6, y: 3)
                            }

                            // Confirm
                            Button {
                                confirmCurrent(expense)
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 64, height: 64)
                                    .background(Circle().fill(.green))
                                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    // MARK: - Swipe overlay labels

    @ViewBuilder
    private var swipeLabel: some View {
        ZStack {
            if dragOffset.width > 40 {
                Text(NSLocalizedString("swipe.label.confirm", comment: ""))
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.green)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.green, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(-15))
                    .opacity(min(1, Double(dragOffset.width - 40) / 80))
                    .padding(.top, 40)
            }

            if dragOffset.width < -40 {
                Text(NSLocalizedString("swipe.label.reject", comment: ""))
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.red)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.red, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(15))
                    .opacity(min(1, Double(-dragOffset.width - 40) / 80))
                    .padding(.top, 40)
            }
        }
    }

    // MARK: - Actions

    private func confirmCurrent(_ expense: Expense) {
        let direction: CGFloat = 500
        withAnimation(.easeIn(duration: 0.3)) {
            dragOffset = CGSize(width: direction, height: 0)
            dragRotation = 15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            store.confirm(expense)
            dragOffset = .zero
            dragRotation = 0
            checkDone()
        }
    }

    private func rejectCurrent(_ expense: Expense) {
        let direction: CGFloat = -500
        withAnimation(.easeIn(duration: 0.3)) {
            dragOffset = CGSize(width: direction, height: 0)
            dragRotation = -15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            store.reject(expense)
            dragOffset = .zero
            dragRotation = 0
            checkDone()
        }
    }

    private func checkDone() {
        if pendingExpenses.isEmpty {
            withAnimation(.easeInOut(duration: 0.4)) {
                showDoneState = true
            }
        }
    }
}

// MARK: - Expense Card

private struct ExpenseCard: View {
    let expense: Expense

    var body: some View {
        VStack(spacing: 0) {
            // Top: vendor + confidence
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: expense.source.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(categoryColor)
                }

                Text(expense.vendor)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                ConfidencePill(value: expense.confidence)
            }
            .padding(.top, 28)
            .padding(.horizontal, 20)

            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, 24)

            // Middle: amounts
            VStack(spacing: 12) {
                AmountRow(label: NSLocalizedString("review.field.subtotal", comment: ""), value: Formatters.money(expense.subtotal, currency: expense.currency))
                AmountRow(label: String(format: NSLocalizedString("review.field.tax", comment: ""), "\(expense.ivaRate)"), value: Formatters.money(expense.ivaAmount, currency: expense.currency), color: .blue)
                if expense.irpfAmount != 0 {
                    AmountRow(label: String(format: NSLocalizedString("review.field.withholding", comment: ""), "\(expense.irpfRate)"), value: Formatters.money(expense.irpfAmount, currency: expense.currency), color: .orange)
                }
                Divider().padding(.horizontal, 8)
                HStack {
                    Text(NSLocalizedString("review.field.total", comment: ""))
                        .font(.headline)
                    Spacer()
                    Text(Formatters.money(expense.total, currency: expense.currency))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)
                }
            }
            .padding(.horizontal, 24)

            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, 24)

            // Bottom: details grid
            HStack(spacing: 0) {
                DetailCell(icon: "calendar", label: NSLocalizedString("review.field.date", comment: ""), value: Formatters.shortDate.string(from: expense.date))
                DetailCell(icon: "tag.fill", label: NSLocalizedString("review.field.category", comment: ""), value: expense.category.localizedName)
                DetailCell(icon: "eurosign.circle.fill", label: NSLocalizedString("review.field.currency", comment: ""), value: expense.currency)
            }
            .padding(.horizontal, 16)

            // Invoice number
            if let inv = expense.invoiceNumber, !inv.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(NSLocalizedString("review.field.invoice", comment: "")): \(inv)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            // Vendor / Client tax IDs
            if expense.vendorTaxId != nil || expense.clientTaxId != nil {
                HStack(spacing: 16) {
                    if let vendorTax = expense.vendorTaxId, !vendorTax.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.caption2)
                            Text(vendorTax)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    if let clientTax = expense.clientTaxId, !clientTax.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.caption2)
                            Text(clientTax)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
        )
    }

    private var categoryColor: Color {
        switch expense.source {
        case .gmail: return .red
        case .camera: return .indigo
        case .manual: return .teal
        }
    }
}

private struct AmountRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

private struct DetailCell: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ConfidencePill: View {
    let value: Double

    var body: some View {
        let pct = Int(value * 100)
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(String(format: NSLocalizedString("swipe.confidence", comment: ""), pct))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var icon: String {
        if value >= 0.9 { return "checkmark.seal.fill" }
        if value >= 0.7 { return "exclamationmark.triangle.fill" }
        return "xmark.octagon.fill"
    }

    private var color: Color {
        if value >= 0.9 { return .green }
        if value >= 0.7 { return .orange }
        return .red
    }
}

// MARK: - All Reviewed

private struct AllReviewedView: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appear ? 1 : 0.5)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .scaleEffect(appear ? 1 : 0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appear)

            Text(NSLocalizedString("swipe.done.title", comment: ""))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appear)

            Text(NSLocalizedString("swipe.done.subtitle", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: appear)
        }
        .onAppear { appear = true }
    }
}
