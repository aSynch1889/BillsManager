import Foundation

enum CurrencyFormatter {
    /// Locale-aware parse for decimal-pad input (`12.34` or `12,34`).
    static func parseAmount(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: trimmed) {
            let value = number.doubleValue
            return isValidAmount(value) ? value : nil
        }

        // Fallback: normalize common separators then parse.
        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), isValidAmount(value) else { return nil }
        return value
    }

    static func isValidAmount(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }

    /// Decimal text for form fields (no currency symbol).
    static func inputString(for amount: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    static func string(amount: Double, currencyCode: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount))
            ?? "\(currencyCode) \(String(format: "%.2f", amount))"
    }

    /// Prefer the bill's own currency; fall back to app default / locale.
    static func string(for bill: Bill, locale: Locale = .current) -> String {
        string(amount: bill.amount, currencyCode: bill.currencyCode, locale: locale)
    }

    static func string(
        amount: Double,
        defaultCurrencyCode: String? = nil,
        locale: Locale = .current
    ) -> String {
        let code = defaultCurrencyCode
            ?? Locale.current.currency?.identifier
            ?? "USD"
        return string(amount: amount, currencyCode: code, locale: locale)
    }

    static func isValidLast4(_ text: String) -> Bool {
        text.count == 4 && text.allSatisfy(\.isNumber)
    }
}
