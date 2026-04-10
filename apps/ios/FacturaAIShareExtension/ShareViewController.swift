import UIKit
import Social
import UniformTypeIdentifiers

/// Share extension entry point. Accepts images, PDFs, and generic files from the
/// iOS share sheet, copies them into the shared App Group container, then opens
/// the host app via custom URL scheme so the main app can ingest them.
///
/// SETUP (one-time, in Xcode):
///   1. File → New → Target → Share Extension. Name it "InvoScanAIShareExtension".
///      Replace the generated ShareViewController.swift with this file.
///   2. In both the InvoScanAI target and InvoScanAIShareExtension target, add the
///      App Groups capability and create a group named:
///        group.es.kungfusoftware.invoscanai
///   3. In the extension's Info.plist, set NSExtensionAttributes →
///      NSExtensionActivationRule to allow images, PDFs and files (see
///      Info.plist in this folder).
///   4. The extension's Info.plist already declares it accepts the relevant types.
class ShareViewController: UIViewController {

    private let appGroupId = "group.es.kungfusoftware.invoscanai"
    private let hostScheme = "invoscanai"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        Task { await handleIncoming() }
    }

    private func handleIncoming() async {
        guard
            let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
            let attachments = item.attachments
        else {
            complete()
            return
        }

        var savedPaths: [String] = []
        let supported: [UTType] = [.image, .pdf, .fileURL, .data, .item]

        for provider in attachments {
            for type in supported where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                if let path = await loadAndSave(provider: provider, type: type) {
                    savedPaths.append(path)
                    break
                }
            }
        }

        openHostApp(with: savedPaths)
        complete()
    }

    private func loadAndSave(provider: NSItemProvider, type: UTType) async -> String? {
        await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { data, _ in
                let saved = self.persist(data)
                cont.resume(returning: saved)
            }
        }
    }

    private func persist(_ data: Any?) -> String? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        else { return nil }

        let inbox = container.appendingPathComponent("ShareInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let id = UUID().uuidString
        do {
            if let url = data as? URL {
                let dest = inbox.appendingPathComponent("\(id)-\(url.lastPathComponent)")
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                return dest.lastPathComponent
            }
            if let image = data as? UIImage, let jpeg = image.jpegData(compressionQuality: 0.9) {
                let dest = inbox.appendingPathComponent("\(id).jpg")
                try jpeg.write(to: dest)
                return dest.lastPathComponent
            }
            if let raw = data as? Data {
                let dest = inbox.appendingPathComponent("\(id).bin")
                try raw.write(to: dest)
                return dest.lastPathComponent
            }
        } catch {
            print("[ShareExt] persist failed: \(error)")
        }
        return nil
    }

    private func openHostApp(with files: [String]) {
        guard !files.isEmpty else { return }
        var components = URLComponents()
        components.scheme = hostScheme
        components.host = "share"
        components.queryItems = files.map { URLQueryItem(name: "f", value: $0) }
        guard let url = components.url else { return }

        // Walk the responder chain to find an `openURL:` selector that works in extensions.
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let r = responder {
            if r.responds(to: selector) {
                _ = r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
