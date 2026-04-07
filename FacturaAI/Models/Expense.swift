import Foundation

enum ExpenseStatus: String, Codable, CaseIterable {
    case pending, confirmed, rejected

    var label: String {
        switch self {
        case .pending: return "Pendiente"
        case .confirmed: return "Confirmado"
        case .rejected: return "Rechazado"
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
    case software = "Software y herramientas"
    case suministros = "Suministros"
    case materialOficina = "Material oficina"
    case serviciosProfesionales = "Servicios profesionales"
    case formacion = "Formación"
    case vehiculo = "Vehículo"
    case representacion = "Representación"
    case hosting = "Hosting y cloud"
    case telefonia = "Telefonía e internet"
    case otros = "Otros"
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
