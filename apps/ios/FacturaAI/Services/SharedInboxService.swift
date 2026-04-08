import Foundation

/// Reads files dropped into the App Group container by the Share Extension and
/// hands them to ExpenseStore for OCR/upload. Called when the app is opened via
/// the `facturaai://share?f=...` URL.
@MainActor
final class SharedInboxService {
    static let shared = SharedInboxService()
    private let appGroupId = "group.es.kungfusoftware.facturaai"

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
}
