import Foundation

enum Formatters {
    static let euro: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    static func euro(_ value: Decimal) -> String {
        euro.string(from: value as NSDecimalNumber) ?? "€0,00"
    }

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM yyyy"
        return f
    }()
}
