import Foundation

enum ExpenseStatus: String, Codable, CaseIterable {
    case pending, confirmed, rejected

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .rejected: return "Rejected"
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
}

struct Expense: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
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

    var quarter: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        let q = ((comps.month ?? 1) - 1) / 3 + 1
        return "\(comps.year ?? 0)-Q\(q)"
    }
}
