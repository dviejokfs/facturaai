import Foundation

enum APIError: Error, LocalizedError {
    case notAuthenticated
    case http(Int, String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decoding(let e): return "Decoding: \(e.localizedDescription)"
        case .transport(let e): return "Network: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    /// Override for production / TestFlight.
    var baseURL = URL(string: "http://192.168.1.133:3005")!

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        return URLSession(configuration: cfg)
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "UTC")
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let d = iso.date(from: s) { return d }
            if let d = isoNoFrac.date(from: s) { return d }
            if let d = day.date(from: s) { return d }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(s)")
        }
        return d
    }()

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Auth

    func startGoogleAuthURL() -> URL {
        baseURL.appendingPathComponent("auth/google/start")
    }

    // MARK: - Me

    func me() async throws -> MeResponse {
        try await request("GET", path: "api/me/profile")
    }

    // Use the /auth/me helper (attached by auth routes)
    func meProfile() async throws -> MeResponse {
        try await request("GET", path: "auth/me")
    }

    // MARK: - Expenses

    func listExpenses() async throws -> [RemoteExpense] {
        try await request("GET", path: "api/expenses")
    }

    func patchExpense(id: String, body: [String: Any]) async throws -> RemoteExpense {
        try await request("PATCH", path: "api/expenses/\(id)", jsonBody: body)
    }

    func deleteExpense(id: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/expenses/\(id)")
    }

    func uploadReceipt(imageData: Data, filename: String, mimeType: String) async throws -> RemoteExpense {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = try authorizedRequest("POST", path: "api/expenses/upload")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        return try await send(req)
    }

    // MARK: - Gmail

    func triggerGmailSync() async throws -> GmailSync {
        try await request("POST", path: "api/gmail/sync", jsonBody: [:])
    }

    func getGmailSync(id: String) async throws -> GmailSync {
        try await request("GET", path: "api/gmail/sync/\(id)")
    }

    // MARK: - Export

    func exportCSV(quarter: String, locale: String = LocaleService.current) async throws -> Data {
        var req = try authorizedRequest("GET", path: "api/export/csv?quarter=\(quarter)&locale=\(locale)")
        req.setValue("text/csv", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        return data
    }

    /// Downloads the quarterly ZIP bundle (locale-aware CSV + dual-sheet XLSX + originals).
    func exportZip(quarter: String, locale: String = LocaleService.current) async throws -> URL {
        var req = try authorizedRequest("GET", path: "api/export/zip?quarter=\(quarter)&locale=\(locale)")
        req.setValue("application/zip", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FacturaAI_Export_\(quarter).zip")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Async Export Jobs

    /// Create an export job (returns immediately with stats + warnings, builds ZIP in background).
    func createExportJob(quarter: String, locale: String = LocaleService.current) async throws -> ExportJob {
        try await request("POST", path: "api/export/jobs", jsonBody: [
            "quarter": quarter,
            "locale": locale,
        ])
    }

    /// Poll export job status.
    func getExportJob(id: String) async throws -> ExportJob {
        try await request("GET", path: "api/export/jobs/\(id)")
    }

    /// Download the ZIP from a completed export job.
    func downloadExportJob(id: String) async throws -> URL {
        var req = try authorizedRequest("GET", path: "api/export/jobs/\(id)/download")
        req.setValue("application/zip", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FacturaAI_Export_\(id.prefix(8)).zip")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Create a public share link for a completed export.
    func createShareLink(exportId: String) async throws -> ExportShareResponse {
        try await request("POST", path: "api/export/jobs/\(exportId)/share", jsonBody: [:])
    }

    // MARK: - Profile

    /// Persist locale (and other profile fields) to backend.
    func updateProfile(_ fields: [String: Any]) async throws {
        var req = try authorizedRequest("PATCH", path: "auth/me")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: fields)
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
    }

    // MARK: - Core

    private func authorizedRequest(_ method: String, path: String) throws -> URLRequest {
        guard let token = Keychain.loadToken() else { throw APIError.notAuthenticated }
        var url = baseURL.appendingPathComponent(path)
        if path.contains("?") {
            url = URL(string: baseURL.absoluteString + "/" + path)!
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func request<T: Decodable>(_ method: String, path: String, jsonBody: Any? = nil) async throws -> T {
        var req = try authorizedRequest(method, path: path)
        if let jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        return try await send(req)
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        try validate(resp, data: data)
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func validate(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, body)
        }
    }
}

struct EmptyResponse: Decodable {}

struct MeResponse: Decodable {
    let id: String
    let email: String
    let name: String?
    let plan: String
    let trialEndsAt: Date?
    let trialDaysLeft: Int?
    let trialExpired: Bool?
    let locale: String?
    let baseCurrency: String?
    let taxId: String?
    let taxIdType: String?
    let accountantEmail: String?
    let accountantName: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name, plan, locale
        case trialEndsAt = "trial_ends_at"
        case trialDaysLeft = "trial_days_left"
        case trialExpired = "trial_expired"
        case baseCurrency = "base_currency"
        case taxId = "tax_id"
        case taxIdType = "tax_id_type"
        case accountantEmail = "accountant_email"
        case accountantName = "accountant_name"
    }
}

struct RemoteExpense: Decodable, Identifiable {
    let id: String
    let vendor: String
    let cif: String?
    let date: Date
    let invoiceNumber: String?
    let subtotal: Decimal
    let ivaRate: Decimal
    let ivaAmount: Decimal
    let irpfRate: Decimal
    let irpfAmount: Decimal
    let total: Decimal
    let currency: String
    let category: String
    let status: String
    let confidence: Double
    let source: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, vendor, cif, date, subtotal, total, currency, category, status, confidence, source, notes
        case invoiceNumber = "invoice_number"
        case ivaRate = "iva_rate"
        case ivaAmount = "iva_amount"
        case irpfRate = "irpf_rate"
        case irpfAmount = "irpf_amount"
    }
}

struct GmailSync: Decodable {
    let id: String
    let status: String
    let messagesProcessed: Int?
    let invoicesFound: Int?

    enum CodingKeys: String, CodingKey {
        case id, status
        case messagesProcessed = "messages_processed"
        case invoicesFound = "invoices_found"
    }
}

extension RemoteExpense {
    func toDomain() -> Expense {
        let cat = TaxCategory(rawValue: mapCategoryLabel(category)) ?? .otros
        let src: ExpenseSource = ExpenseSource(rawValue: source) ?? .manual
        let st: ExpenseStatus = ExpenseStatus(rawValue: status) ?? .pending
        return Expense(
            id: UUID(uuidString: id) ?? UUID(),
            vendor: vendor,
            cif: cif,
            date: date,
            invoiceNumber: invoiceNumber,
            subtotal: subtotal,
            ivaRate: ivaRate,
            ivaAmount: ivaAmount,
            irpfRate: irpfRate,
            irpfAmount: irpfAmount,
            total: total,
            currency: currency,
            category: cat,
            status: st,
            confidence: confidence,
            source: src,
            notes: notes,
            attachmentName: nil
        )
    }
}

// MARK: - Export Job Models

struct ExportJobStats: Decodable {
    let byCurrency: [String: ExportCurrencyStats]?
}

struct ExportCurrencyStats: Decodable {
    let count: Int
    let subtotal: Double
    let tax: Double
    let total: Double
}

struct ExportWarning: Decodable, Identifiable {
    let type: String
    let count: Int
    let message: String
    var id: String { type }
}

struct ExportJob: Decodable, Identifiable {
    let id: String
    let status: String
    let progress: Int?
    let stats: ExportJobStats?
    let warnings: [ExportWarning]?
    let expenseCount: Int?
    let storageKey: String?
    let createdAt: String?
    let expiresAt: String?

    var isReady: Bool { status == "ready" }
    var isFailed: Bool { status == "failed" }
    var isProcessing: Bool { status == "pending" || status == "running" }
}

struct ExportShareResponse: Decodable {
    let token: String
    let url: String
    let expiresAt: String
}

private func mapCategoryLabel(_ key: String) -> String {
    switch key {
    case "software": return TaxCategory.software.rawValue
    case "suministros": return TaxCategory.suministros.rawValue
    case "materialOficina": return TaxCategory.materialOficina.rawValue
    case "serviciosProfesionales": return TaxCategory.serviciosProfesionales.rawValue
    case "formacion": return TaxCategory.formacion.rawValue
    case "vehiculo": return TaxCategory.vehiculo.rawValue
    case "representacion": return TaxCategory.representacion.rawValue
    case "hosting": return TaxCategory.hosting.rawValue
    case "telefonia": return TaxCategory.telefonia.rawValue
    default: return TaxCategory.otros.rawValue
    }
}
