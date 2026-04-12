import Foundation

/// Reads files dropped into the App Group container by the Share Extension and
/// hands them to ExpenseStore for OCR/upload. Called when the app is opened via
/// the `invoscanai://share?f=...` URL.
@MainActor
final class SharedInboxService {
    static let shared = SharedInboxService()
    private let appGroupId = "group.es.kungfusoftware.invoscanai"

    private var inboxURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent("ShareInbox", isDirectory: true)
    }

    /// Pull all files referenced by the URL (or every file in the inbox if none
    /// are listed) and upload them via the existing expense upload pipeline.
    func ingest(from url: URL, store: ExpenseStore) async {
        guard let inbox = inboxURL else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let names = comps?.queryItems?.compactMap { $0.name == "f" ? $0.value : nil } ?? []

        let files: [URL]
        if names.isEmpty {
            files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
        } else {
            files = names.map { inbox.appendingPathComponent($0) }
        }

        for file in files {
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            do {
                let data = try Data(contentsOf: file)
                await store.uploadSharedFile(data: data, filename: file.lastPathComponent)
                try? FileManager.default.removeItem(at: file)
            } catch {
                print("[SharedInbox] failed for \(file.lastPathComponent): \(error)")
            }
        }
    }

    /// Handles "Open In InvoScanAI…" opens from Files/Mail/Safari where iOS passes
    /// a `file://` URL directly. Uses security-scoped access because the file lives
    /// outside our sandbox (in a document-picker-vended location).
    func ingestFile(at url: URL, store: ExpenseStore) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            await store.uploadSharedFile(data: data, filename: url.lastPathComponent)
        } catch {
            print("[SharedInbox] ingestFile failed for \(url.lastPathComponent): \(error)")
        }
    }
}
