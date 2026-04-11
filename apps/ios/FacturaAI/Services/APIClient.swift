import Foundation

/// Reason the backend returned a 403 with `upgrade: true`.
enum UpgradeReason: String {
    case limitReached = "limit_reached"
    case trialExpired = "trial_expired"
    case unknown
}

enum APIError: Error, LocalizedError {
    case notAuthenticated
    case upgradeNeeded(UpgradeReason)
    case http(Int, String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated"
        case .upgradeNeeded: return "Upgrade required"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decoding(let e): return "Decoding: \(e.localizedDescription)"
        case .transport(let e): return "Network: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    /// Reads API base URL from Info.plist (API_BASE_URL).
    /// Falls back to localhost for development.
    var baseURL: URL = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL not set in Info.plist for production build")
        }
        return url
    }()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
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

    func downloadAttachment(expenseId: String) async throws -> (Data, String) {
        let req = try authorizedRequest("GET", path: "api/expenses/\(expenseId)/attachment")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? 0, String(data: data, encoding: .utf8) ?? "")
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
        return (data, contentType)
    }

    func uploadReceipt(imageData: Data, filename: String, mimeType: String) async throws -> RemoteExpense {
        let fileURL = try writeMultipartTempFile(data: imageData, filename: filename, mimeType: mimeType)
        defer { try? FileManager.default.removeItem(at: fileURL.tempFile) }

        var req = try authorizedRequest("POST", path: "api/expenses/upload")
        req.setValue("multipart/form-data; boundary=\(fileURL.boundary)", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await session.upload(for: req, fromFile: fileURL.tempFile)
        try validate(resp, data: data)
        do {
            return try decoder.decode(RemoteExpense.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Upload from a file URL instead of in-memory Data. Avoids loading large PDFs into memory.
    func uploadReceiptFromFile(fileURL: URL, filename: String, mimeType: String) async throws -> RemoteExpense {
        let tempFile = try writeMultipartTempFileFromURL(sourceURL: fileURL, filename: filename, mimeType: mimeType)
        defer { try? FileManager.default.removeItem(at: tempFile.tempFile) }

        var req = try authorizedRequest("POST", path: "api/expenses/upload")
        req.setValue("multipart/form-data; boundary=\(tempFile.boundary)", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await session.upload(for: req, fromFile: tempFile.tempFile)
        try validate(resp, data: data)
        do {
            return try decoder.decode(RemoteExpense.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Anonymous extraction — creates/reuses anonymous user. Returns extracted data + anonymous JWT.
    func extractOnly(imageData: Data, filename: String, mimeType: String, companyName: String? = nil) async throws -> ExtractedResponse {
        let fileURL = try writeMultipartTempFile(data: imageData, filename: filename, mimeType: mimeType, companyName: companyName)
        defer { try? FileManager.default.removeItem(at: fileURL.tempFile) }

        let url = baseURL.appendingPathComponent("api/extract")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(fileURL.boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let anonToken = Keychain.loadAnonymousToken() {
            req.setValue("Bearer \(anonToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await session.upload(for: req, fromFile: fileURL.tempFile)

        // Always try to save the anonymous token, even from error responses
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let anonToken = json["anonymous_token"] as? String {
            Keychain.saveAnonymousToken(anonToken)
        }

        try validate(resp, data: data)

        do {
            return try decoder.decode(ExtractedResponse.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// File-based extraction — avoids loading large PDFs into memory entirely.
    func extractOnlyFromFile(fileURL: URL, filename: String, mimeType: String, companyName: String? = nil) async throws -> ExtractedResponse {
        let tempFile = try writeMultipartTempFileFromURL(sourceURL: fileURL, filename: filename, mimeType: mimeType, companyName: companyName)
        defer { try? FileManager.default.removeItem(at: tempFile.tempFile) }

        let url = baseURL.appendingPathComponent("api/extract")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(tempFile.boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let anonToken = Keychain.loadAnonymousToken() {
            req.setValue("Bearer \(anonToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await session.upload(for: req, fromFile: tempFile.tempFile)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let anonToken = json["anonymous_token"] as? String {
            Keychain.saveAnonymousToken(anonToken)
        }

        try validate(resp, data: data)

        do {
            return try decoder.decode(ExtractedResponse.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Multipart temp file helpers

    private struct MultipartTempFile {
        let tempFile: URL
        let boundary: String
    }

    /// Write in-memory Data to a multipart temp file for streaming upload.
    private func writeMultipartTempFile(data: Data, filename: String, mimeType: String, companyName: String? = nil) throws -> MultipartTempFile {
        let boundary = "Boundary-\(UUID().uuidString)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        var preamble = ""
        if let companyName, !companyName.isEmpty {
            preamble = "--\(boundary)\r\nContent-Disposition: form-data; name=\"company_name\"\r\n\r\n\(companyName)\r\n"
        }
        let header = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\nContent-Type: \(mimeType)\r\n\r\n"
        let footer = "\r\n--\(boundary)--\r\n"

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        handle.write(preamble.data(using: .utf8)!)
        handle.write(header.data(using: .utf8)!)
        handle.write(data)
        handle.write(footer.data(using: .utf8)!)
        handle.closeFile()

        return MultipartTempFile(tempFile: tempURL, boundary: boundary)
    }

    /// Write a file URL to a multipart temp file — never loads the full file into memory.
    private func writeMultipartTempFileFromURL(sourceURL: URL, filename: String, mimeType: String, companyName: String? = nil) throws -> MultipartTempFile {
        let boundary = "Boundary-\(UUID().uuidString)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        var preamble = ""
        if let companyName, !companyName.isEmpty {
            preamble = "--\(boundary)\r\nContent-Disposition: form-data; name=\"company_name\"\r\n\r\n\(companyName)\r\n"
        }
        let header = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\nContent-Type: \(mimeType)\r\n\r\n"
        let footer = "\r\n--\(boundary)--\r\n"

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: tempURL)
        output.write(preamble.data(using: .utf8)!)
        output.write(header.data(using: .utf8)!)

        // Stream source file in chunks to avoid loading it all into memory
        let input = try FileHandle(forReadingFrom: sourceURL)
        let chunkSize = 64 * 1024 // 64KB chunks
        while autoreleasepool(invoking: {
            let chunk = input.readData(ofLength: chunkSize)
            if chunk.isEmpty { return false }
            output.write(chunk)
            return true
        }) {}
        input.closeFile()

        output.write(footer.data(using: .utf8)!)
        output.closeFile()

        return MultipartTempFile(tempFile: tempURL, boundary: boundary)
    }

    // MARK: - Gmail

    func triggerGmailSync() async throws -> GmailSync {
        try await request("POST", path: "api/gmail/sync", jsonBody: [:])
    }

    func getGmailSync(id: String) async throws -> GmailSync {
        try await request("GET", path: "api/gmail/sync/\(id)")
    }

    func listGmailSyncs() async throws -> [GmailSync] {
        try await request("GET", path: "api/gmail/sync")
    }

    /// Returns the most recent active (running/queued) sync, or the latest completed one.
    /// Returns nil if no syncs exist.
    func getActiveGmailSync() async throws -> GmailSync? {
        try await request("GET", path: "api/gmail/sync/active")
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
            .appendingPathComponent("InvoScanAI_Export_\(quarter).zip")
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
            .appendingPathComponent("InvoScanAI_Export_\(id.prefix(8)).zip")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Create a public share link for a completed export.
    func createShareLink(exportId: String) async throws -> ExportShareResponse {
        try await request("POST", path: "api/export/jobs/\(exportId)/share", jsonBody: [:])
    }

    func sendExportEmail(exportId: String, email: String? = nil) async throws -> ExportEmailResponse {
        var body: [String: Any] = [:]
        if let e = email { body["email"] = e }
        return try await request("POST", path: "api/export/jobs/\(exportId)/share/email", jsonBody: body)
    }

    // MARK: - Companies

    func listCompanies() async throws -> [RemoteCompany] {
        try await request("GET", path: "api/companies")
    }

    func createCompany(name: String, taxId: String, taxIdType: String? = nil, address: String? = nil, isDefault: Bool = false) async throws -> RemoteCompany {
        var body: [String: Any] = ["name": name, "taxId": taxId, "isDefault": isDefault]
        if let t = taxIdType { body["taxIdType"] = t }
        if let a = address { body["address"] = a }
        return try await request("POST", path: "api/companies", jsonBody: body)
    }

    func updateCompany(id: String, body: [String: Any]) async throws -> RemoteCompany {
        try await request("PATCH", path: "api/companies/\(id)", jsonBody: body)
    }

    func deleteCompany(id: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/companies/\(id)")
    }

    // MARK: - Contacts

    func listContacts(query: String? = nil) async throws -> [RemoteContact] {
        let path = query != nil ? "api/contacts?q=\(query!)" : "api/contacts"
        return try await request("GET", path: path)
    }

    func createContact(name: String, taxId: String? = nil, email: String? = nil) async throws -> RemoteContact {
        var body: [String: Any] = ["name": name]
        if let t = taxId { body["taxId"] = t }
        if let e = email { body["email"] = e }
        return try await request("POST", path: "api/contacts", jsonBody: body)
    }

    func deleteContact(id: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/contacts/\(id)")
    }

    // MARK: - Devices (Push Notifications)

    func registerDevice(token: String, platform: String = "ios") async throws {
        let _: EmptyResponse = try await request("POST", path: "api/devices", jsonBody: [
            "token": token,
            "platform": platform
        ])
    }

    // MARK: - GDPR Data Export

    /// Download a full GDPR personal-data export as a JSON file.
    func exportPersonalData() async throws -> URL {
        let req = try authorizedRequest("GET", path: "api/account/export")
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoScanAI_MyData.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        let _: EmptyResponse = try await request("DELETE", path: "auth/account")
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
            print("[APIClient] Decoding \(T.self) failed: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("[APIClient] Raw response: \(raw.prefix(500))")
            }
            throw APIError.decoding(error)
        }
    }

    private func validate(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""

            // Detect 403 with upgrade payload from the backend
            if http.statusCode == 403,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["upgrade"] as? Bool == true {
                let errorKey = json["error"] as? String ?? ""
                let reason = UpgradeReason(rawValue: errorKey) ?? .unknown
                // Post notification so the UI can present a paywall automatically
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .upgradeNeeded,
                        object: reason
                    )
                }
                throw APIError.upgradeNeeded(reason)
            }

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
    let gmailConnected: Bool?
    let googleTokenExpiry: Date?
    let googleHasRefreshToken: Bool?
    let companyName: String?

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
        case gmailConnected = "gmail_connected"
        case googleTokenExpiry = "google_token_expiry"
        case googleHasRefreshToken = "google_has_refresh_token"
        case companyName = "company_name"
    }
}

struct RemoteExpense: Decodable, Identifiable {
    let id: String
    let type: String?
    let vendor: String
    let vendorTaxId: String?
    let client: String?
    let clientTaxId: String?
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
    let companyId: String?
    let vendorContactId: String?
    let clientContactId: String?
    let attachmentKey: String?

    enum CodingKeys: String, CodingKey {
        case id, type, vendor, cif, date, subtotal, total, currency, category, status, confidence, source, notes, client
        case vendorTaxId = "vendor_tax_id"
        case clientTaxId = "client_tax_id"
        case invoiceNumber = "invoice_number"
        case ivaRate = "iva_rate"
        case ivaAmount = "iva_amount"
        case irpfRate = "irpf_rate"
        case irpfAmount = "irpf_amount"
        case companyId = "company_id"
        case vendorContactId = "vendor_contact_id"
        case clientContactId = "client_contact_id"
        case attachmentKey = "attachment_key"
    }
}

struct GmailSync: Decodable {
    let id: String
    let status: String
    let messagesProcessed: Int?
    let invoicesFound: Int?
    let totalMessages: Int?
    let error: String?
    let lastSyncAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, error
        case messagesProcessed = "messages_processed"
        case invoicesFound = "invoices_found"
        case totalMessages = "total_messages"
        case lastSyncAt = "last_sync_at"
        case createdAt = "created_at"
    }

    var isComplete: Bool { status == "completed" || status == "failed" }
}

extension RemoteExpense {
    func toDomain() -> Expense {
        let cat = TaxCategory(rawValue: mapCategoryLabel(category)) ?? .otros
        let src: ExpenseSource = ExpenseSource(rawValue: source) ?? .manual
        let st: ExpenseStatus = ExpenseStatus(rawValue: status) ?? .pending
        let txType = TransactionType(rawValue: type ?? "expense") ?? .expense
        return Expense(
            id: UUID(uuidString: id) ?? UUID(),
            type: txType,
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
            attachmentName: attachmentKey?.split(separator: "/").last.map(String.init),
            hasRemoteAttachment: attachmentKey != nil,
            vendorTaxId: vendorTaxId,
            client: client,
            clientTaxId: clientTaxId,
            companyId: companyId != nil ? UUID(uuidString: companyId!) : nil,
            vendorContactId: vendorContactId != nil ? UUID(uuidString: vendorContactId!) : nil,
            clientContactId: clientContactId != nil ? UUID(uuidString: clientContactId!) : nil
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

struct ExportEmailResponse: Decodable {
    let ok: Bool
    let sentTo: String
}

struct ExtractedResponse: Decodable {
    let vendor: String
    let vendorTaxId: String?
    let client: String?
    let clientTaxId: String?
    let cif: String?
    let date: String // "YYYY-MM-DD"
    let invoiceNumber: String?
    let subtotal: Decimal
    let ivaRate: Decimal
    let ivaAmount: Decimal
    let irpfRate: Decimal
    let irpfAmount: Decimal
    let total: Decimal
    let currency: String
    let category: String
    let confidence: Double
    let isValidInvoice: Bool
    let isExpense: Bool?
    let anonymousToken: String?

    // Backend returns camelCase keys; anonymous_token is the only snake_case one
    enum CodingKeys: String, CodingKey {
        case vendor, vendorTaxId, client, clientTaxId, cif, date, invoiceNumber
        case subtotal, ivaRate, ivaAmount, irpfRate, irpfAmount, total
        case currency, category, confidence, isValidInvoice, isExpense
        case anonymousToken = "anonymous_token"
    }
}

extension ExtractedResponse {
    func toDomain() -> Expense {
        let cat = TaxCategory(rawValue: mapCategoryLabel(category)) ?? .otros
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let parsedDate = fmt.date(from: date) ?? Date()
        let txType: TransactionType = (isExpense == false) ? .income : .expense
        return Expense(
            type: txType,
            vendor: vendor,
            cif: cif,
            date: parsedDate,
            invoiceNumber: invoiceNumber,
            subtotal: subtotal,
            ivaRate: ivaRate,
            ivaAmount: ivaAmount,
            irpfRate: irpfRate,
            irpfAmount: irpfAmount,
            total: total,
            currency: currency,
            category: cat,
            status: .pending,
            confidence: confidence,
            source: .camera,
            vendorTaxId: vendorTaxId,
            client: client,
            clientTaxId: clientTaxId
        )
    }
}

// MARK: - Company & Contact Models

struct RemoteCompany: Decodable, Identifiable {
    let id: String
    let name: String
    let taxId: String
    let taxIdType: String?
    let address: String?
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, address
        case taxId = "tax_id"
        case taxIdType = "tax_id_type"
        case isDefault = "is_default"
    }
}

struct RemoteContact: Decodable, Identifiable {
    let id: String
    let name: String
    let taxId: String?
    let email: String?
    let phone: String?
    let address: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, address, notes
        case taxId = "tax_id"
    }
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
