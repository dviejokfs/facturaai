import Foundation

enum CSVExporter {
    static func csv(for expenses: [Expense]) -> String {
        var out = "Date,Vendor,TaxID,InvoiceNumber,Subtotal,TaxRate%,TaxAmount,WithholdingRate%,WithholdingAmount,Total,Category,Status\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        for e in expenses {
            let fields: [String] = [
                df.string(from: e.date),
                escape(e.vendor),
                e.cif ?? "",
                e.invoiceNumber ?? "",
                "\(e.subtotal)",
                "\(e.ivaRate)",
                "\(e.ivaAmount)",
                "\(e.irpfRate)",
                "\(e.irpfAmount)",
                "\(e.total)",
                escape(e.category.rawValue),
                e.status.rawValue
            ]
            out += fields.joined(separator: ",") + "\n"
        }
        return out
    }

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    static func writeTempFile(csv: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
