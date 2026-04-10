import Foundation
import SwiftUI

/// Single source of truth for the user's preferred locale. Resolution order:
///   1. Explicit user choice persisted in UserDefaults (Settings → Language)
///   2. iOS system locale (Locale.current)
///   3. Fallback "en-GB" (matches backend default)
@MainActor
final class LocaleService: ObservableObject {
    static let shared = LocaleService()

    /// Locales we currently ship UI + export translations for. Adding a new
    /// market is: drop strings file + add a case here + ship a backend locale.
    nonisolated static let supported: [String] = ["en-GB", "es-ES"]

    private let key = "invoscanai.user_locale"

    @Published var override: String? {
        didSet {
            if let v = override { UserDefaults.standard.set(v, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
    }

    init() {
        self.override = UserDefaults.standard.string(forKey: key)
    }

    /// The locale string sent to the backend on every export call.
    nonisolated static var current: String {
        if let saved = UserDefaults.standard.string(forKey: "invoscanai.user_locale"),
           supported.contains(saved) {
            return saved
        }
        // Try exact system match, then language-only match.
        let system = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        if supported.contains(system) { return system }
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        if let match = supported.first(where: { $0.hasPrefix(lang) }) { return match }
        return "en-GB"
    }

    var current: String { Self.current }

    func displayName(for code: String) -> String {
        let id = Locale(identifier: code)
        return id.localizedString(forIdentifier: code)?.capitalized ?? code
    }
}
