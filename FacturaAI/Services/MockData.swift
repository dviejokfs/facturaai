import Foundation

enum MockData {
    static func sampleExpenses() -> [Expense] {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now)! }

        return [
            Expense(vendor: "Amazon Web Services", cif: "W0184081H", date: daysAgo(2),
                    invoiceNumber: "EUINGB24-1234567", subtotal: 142.50, ivaRate: 21, ivaAmount: 29.93,
                    irpfRate: 0, irpfAmount: 0, total: 172.43, category: .hosting,
                    status: .confirmed, confidence: 0.98, source: .gmail, attachmentName: "aws-invoice.pdf"),
            Expense(vendor: "Stripe Payments Europe", cif: "IE3206488LH", date: daysAgo(5),
                    invoiceNumber: "INV-8847291", subtotal: 24.90, ivaRate: 21, ivaAmount: 5.23,
                    irpfRate: 0, irpfAmount: 0, total: 30.13, category: .software,
                    status: .confirmed, confidence: 0.99, source: .gmail),
            Expense(vendor: "Figma Inc", cif: nil, date: daysAgo(8),
                    invoiceNumber: "FIG-2026-0412", subtotal: 15.00, ivaRate: 21, ivaAmount: 3.15,
                    irpfRate: 0, irpfAmount: 0, total: 18.15, category: .software,
                    status: .pending, confidence: 0.87, source: .gmail),
            Expense(vendor: "Bar Pepe", cif: "B12345678", date: daysAgo(12),
                    invoiceNumber: "2026/0421", subtotal: 13.64, ivaRate: 10, ivaAmount: 1.36,
                    irpfRate: 0, irpfAmount: 0, total: 15.00, category: .representacion,
                    status: .pending, confidence: 0.72, source: .camera),
            Expense(vendor: "Vodafone España", cif: "A80907397", date: daysAgo(15),
                    invoiceNumber: "VF-2026-03-998", subtotal: 45.45, ivaRate: 21, ivaAmount: 9.55,
                    irpfRate: 0, irpfAmount: 0, total: 55.00, category: .telefonia,
                    status: .confirmed, confidence: 0.96, source: .gmail),
            Expense(vendor: "Notion Labs", cif: nil, date: daysAgo(22),
                    invoiceNumber: "NOT-99812", subtotal: 8.00, ivaRate: 21, ivaAmount: 1.68,
                    irpfRate: 0, irpfAmount: 0, total: 9.68, category: .software,
                    status: .confirmed, confidence: 0.94, source: .gmail),
            Expense(vendor: "Udemy", cif: nil, date: daysAgo(30),
                    invoiceNumber: "UD-7612", subtotal: 19.99, ivaRate: 21, ivaAmount: 4.20,
                    irpfRate: 0, irpfAmount: 0, total: 24.19, category: .formacion,
                    status: .pending, confidence: 0.91, source: .gmail),
            Expense(vendor: "Repsol", cif: "A78374725", date: daysAgo(35),
                    invoiceNumber: "REP-11928", subtotal: 49.58, ivaRate: 21, ivaAmount: 10.42,
                    irpfRate: 0, irpfAmount: 0, total: 60.00, category: .vehiculo,
                    status: .confirmed, confidence: 0.88, source: .camera),
            Expense(vendor: "MediaMarkt", cif: "A28629197", date: daysAgo(45),
                    invoiceNumber: "MM-2026-4412", subtotal: 198.35, ivaRate: 21, ivaAmount: 41.65,
                    irpfRate: 0, irpfAmount: 0, total: 240.00, category: .materialOficina,
                    status: .confirmed, confidence: 0.95, source: .gmail),
            Expense(vendor: "Gestoría Martínez", cif: "B87123456", date: daysAgo(60),
                    invoiceNumber: "GM-2026-0089", subtotal: 120.00, ivaRate: 21, ivaAmount: 25.20,
                    irpfRate: 15, irpfAmount: 18.00, total: 127.20, category: .serviciosProfesionales,
                    status: .confirmed, confidence: 0.99, source: .gmail),
        ]
    }
}
