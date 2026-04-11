import Foundation

/// Seeds realistic mock data for App Store screenshot generation.
/// Activated by `-UITestScreenshotMode` launch argument.
enum ScreenshotData {

    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestScreenshotMode")
    }

    @MainActor
    static func seedAuth(_ auth: AuthService) {
        auth.isSignedIn = true
        auth.userEmail = "david@kungfusoftware.es"
        auth.plan = "pro"
        auth.trialDaysLeft = 0
        auth.trialExpired = false
        auth.gmailConnected = true
        auth.companyName = "Kung Fu Software SL"
        auth.taxId = "B12345678"
        auth.accountantName = "María García"
        auth.accountantEmail = "maria@gestoria.es"
    }

    @MainActor
    static func seedStore(_ store: ExpenseStore) {
        let cal = Calendar.current
        let now = Date()

        func date(daysAgo: Int) -> Date {
            cal.date(byAdding: .day, value: -daysAgo, to: now)!
        }

        store.expenses = [
            // Income 1
            Expense(
                type: .income,
                vendor: "Kung Fu Software SL",
                date: date(daysAgo: 2),
                invoiceNumber: "KFS-2026-042",
                subtotal: 5000,
                ivaRate: 21,
                ivaAmount: 1050,
                irpfRate: 15,
                irpfAmount: 750,
                total: 5300,
                category: .serviciosProfesionales,
                status: .confirmed,
                confidence: 0.97,
                source: .gmail,
                client: "TechCorp Madrid SL",
                clientTaxId: "B98765432"
            ),
            // Income 2
            Expense(
                type: .income,
                vendor: "Kung Fu Software SL",
                date: date(daysAgo: 15),
                invoiceNumber: "KFS-2026-041",
                subtotal: 3500,
                ivaRate: 21,
                ivaAmount: 735,
                irpfRate: 15,
                irpfAmount: 525,
                total: 3710,
                category: .serviciosProfesionales,
                status: .confirmed,
                confidence: 0.95,
                source: .gmail,
                client: "Startup Valencia SL",
                clientTaxId: "B55667788"
            ),
            // Expense — AWS
            Expense(
                type: .expense,
                vendor: "Amazon Web Services",
                date: date(daysAgo: 3),
                invoiceNumber: "INV-2026-1847",
                subtotal: 142.50,
                ivaRate: 21,
                ivaAmount: 29.93,
                irpfRate: 0,
                irpfAmount: 0,
                total: 172.43,
                category: .hosting,
                status: .confirmed,
                confidence: 0.98,
                source: .gmail,
                vendorTaxId: "W0185840B"
            ),
            // Expense — Apple
            Expense(
                type: .expense,
                vendor: "Apple Inc.",
                date: date(daysAgo: 5),
                invoiceNumber: "APL-849302",
                subtotal: 99,
                ivaRate: 21,
                ivaAmount: 20.79,
                irpfRate: 0,
                irpfAmount: 0,
                total: 119.79,
                category: .software,
                status: .confirmed,
                confidence: 0.96,
                source: .camera
            ),
            // Expense — Vodafone (pending)
            Expense(
                type: .expense,
                vendor: "Vodafone España",
                date: date(daysAgo: 8),
                invoiceNumber: "VF-2026-03-1234",
                subtotal: 45,
                ivaRate: 21,
                ivaAmount: 9.45,
                irpfRate: 0,
                irpfAmount: 0,
                total: 54.45,
                category: .telefonia,
                status: .pending,
                confidence: 0.94,
                source: .gmail,
                vendorTaxId: "A80907397"
            ),
            // Expense — Figma
            Expense(
                type: .expense,
                vendor: "Figma Inc.",
                date: date(daysAgo: 12),
                invoiceNumber: "FIG-2026-8821",
                subtotal: 12,
                ivaRate: 21,
                ivaAmount: 2.52,
                irpfRate: 0,
                irpfAmount: 0,
                total: 14.52,
                category: .software,
                status: .confirmed,
                confidence: 0.99,
                source: .gmail
            ),
            // Expense — Restaurant
            Expense(
                type: .expense,
                vendor: "Restaurante El Molino",
                date: date(daysAgo: 18),
                invoiceNumber: "MOL-0392",
                subtotal: 68.50,
                ivaRate: 10,
                ivaAmount: 6.85,
                irpfRate: 0,
                irpfAmount: 0,
                total: 75.35,
                category: .representacion,
                status: .confirmed,
                confidence: 0.88,
                source: .camera,
                vendorTaxId: "B11223344"
            ),
            // Expense — Repsol
            Expense(
                type: .expense,
                vendor: "Repsol SA",
                date: date(daysAgo: 20),
                invoiceNumber: "REP-2026-44821",
                subtotal: 52.07,
                ivaRate: 21,
                ivaAmount: 10.93,
                irpfRate: 0,
                irpfAmount: 0,
                total: 63,
                category: .vehiculo,
                status: .confirmed,
                confidence: 0.92,
                source: .camera,
                vendorTaxId: "A28223258"
            ),
            // Expense — Notion
            Expense(
                type: .expense,
                vendor: "Notion Labs Inc.",
                date: date(daysAgo: 25),
                invoiceNumber: "NOT-2026-1122",
                subtotal: 8,
                ivaRate: 21,
                ivaAmount: 1.68,
                irpfRate: 0,
                irpfAmount: 0,
                total: 9.68,
                category: .software,
                status: .confirmed,
                confidence: 0.97,
                source: .gmail
            ),
            // Older quarter — Google Cloud
            Expense(
                type: .expense,
                vendor: "Google Cloud",
                date: date(daysAgo: 45),
                invoiceNumber: "GCP-2026-7788",
                subtotal: 230,
                ivaRate: 21,
                ivaAmount: 48.30,
                irpfRate: 0,
                irpfAmount: 0,
                total: 278.30,
                category: .hosting,
                status: .confirmed,
                confidence: 0.96,
                source: .gmail
            ),
            // Older quarter — Income
            Expense(
                type: .income,
                vendor: "Kung Fu Software SL",
                date: date(daysAgo: 50),
                invoiceNumber: "KFS-2026-039",
                subtotal: 4200,
                ivaRate: 21,
                ivaAmount: 882,
                irpfRate: 15,
                irpfAmount: 630,
                total: 4452,
                category: .serviciosProfesionales,
                status: .confirmed,
                confidence: 0.96,
                source: .gmail,
                client: "DataFlow Analytics SL",
                clientTaxId: "B44556677"
            ),
        ]

        store.lastSyncDate = cal.date(byAdding: .hour, value: -2, to: now)
    }
}
