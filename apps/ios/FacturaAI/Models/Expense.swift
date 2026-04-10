import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case expense, income

    var label: String {
        switch self {
        case .expense: return NSLocalizedString("transaction.expense", comment: "")
        case .income: return NSLocalizedString("transaction.income", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        }
    }
}

enum ExpenseStatus: String, Codable, CaseIterable {
    case pending, confirmed, rejected

    var label: String {
        switch self {
        case .pending: return NSLocalizedString("expenses.status.pending", comment: "")
        case .confirmed: return NSLocalizedString("expenses.filter.confirmed", comment: "")
        case .rejected: return NSLocalizedString("expenses.status.rejected", comment: "")
        }
    }
}

enum ExpenseSource: String, Codable {
    case gmail, camera, manual

    var icon: String {
        switch self {
        case .gmail: return "envelope.fill"
        case .camera: return "camera.fill"
        case .manual: return "square.and.pencil"
        }
    }
}

enum TaxCategory: String, Codable, CaseIterable {
    case software = "Software & tools"
    case suministros = "Utilities"
    case materialOficina = "Office supplies"
    case serviciosProfesionales = "Professional services"
    case formacion = "Training"
    case vehiculo = "Vehicle"
    case representacion = "Business meals"
    case hosting = "Hosting & cloud"
    case telefonia = "Phone & internet"
    case otros = "Other"

    var localizedName: String {
        switch self {
        case .software: return NSLocalizedString("category.software", comment: "")
        case .suministros: return NSLocalizedString("category.utilities", comment: "")
        case .materialOficina: return NSLocalizedString("category.office", comment: "")
        case .serviciosProfesionales: return NSLocalizedString("category.professional", comment: "")
        case .formacion: return NSLocalizedString("category.training", comment: "")
        case .vehiculo: return NSLocalizedString("category.vehicle", comment: "")
        case .representacion: return NSLocalizedString("category.meals", comment: "")
        case .hosting: return NSLocalizedString("category.hosting", comment: "")
        case .telefonia: return NSLocalizedString("category.phone", comment: "")
        case .otros: return NSLocalizedString("category.other", comment: "")
        }
    }
}

struct Expense: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: TransactionType = .expense
    var vendor: String
    var cif: String?
    var date: Date
    var invoiceNumber: String?
    var subtotal: Decimal
    var ivaRate: Decimal
    var ivaAmount: Decimal
    var irpfRate: Decimal
    var irpfAmount: Decimal
    var total: Decimal
    var currency: String = "EUR"
    var category: TaxCategory
    var status: ExpenseStatus = .pending
    var confidence: Double
    var source: ExpenseSource
    var notes: String?
    var attachmentName: String?
    var hasRemoteAttachment: Bool = false
    var vendorTaxId: String?
    var client: String?
    var clientTaxId: String?
    var companyId: UUID?
    var vendorContactId: UUID?
    var clientContactId: UUID?

    var quarter: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        let q = ((comps.month ?? 1) - 1) / 3 + 1
        return "\(comps.year ?? 0)-Q\(q)"
    }
}
