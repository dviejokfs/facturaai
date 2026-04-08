import Foundation

enum Formatters {
    /// Currency-aware formatter. Uses the expense's own ISO-4217 code — NEVER converts.
    static func money(_ value: Decimal, currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.locale = Locale.autoupdatingCurrent
        return f.string(from: value as NSDecimalNumber) ?? "\(value) \(currency)"
    }

    /// Convenience for single-currency contexts (defaults to EUR).
    static func euro(_ value: Decimal) -> String {
        money(value, currency: "EUR")
    }

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.dateFormat = "d MMM yyyy"
        return f
    }()
}
