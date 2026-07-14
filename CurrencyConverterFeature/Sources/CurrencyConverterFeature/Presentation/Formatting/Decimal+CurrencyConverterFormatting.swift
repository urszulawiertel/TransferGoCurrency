import Foundation

extension Decimal {
    var isWholeAmount: Bool {
        var value = self
        var integerValue = Decimal()
        NSDecimalRound(&integerValue, &value, 0, .down)
        return integerValue == value
    }

    func currencyConverterFormatted(
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 2,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.locale = locale

        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    static func currencyConverterDecimal(from text: String) -> Decimal? {
        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !normalizedText.isEmpty else {
            return 0
        }

        return Decimal(string: normalizedText, locale: Locale(identifier: "en_US_POSIX"))
    }
}

struct CurrencyAmountEditingFormatter {
    let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func string(from value: Decimal) -> String {
        formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    func decimal(from text: String) -> Decimal? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return 0
        }

        guard isValidEditingText(trimmedText),
              let number = formatter.number(from: trimmedText) else {
            return nil
        }

        return number.decimalValue
    }

    func isValidEditingText(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return true }

        let separator = formatter.decimalSeparator ?? "."
        let parts = trimmedText.components(separatedBy: separator)
        guard parts.count <= 2,
              parts[0].allSatisfy(\.isNumber),
              parts.count == 1 || parts[1].allSatisfy(\.isNumber),
              parts.count == 1 || parts[1].count <= 2 else {
            return false
        }

        return !parts[0].isEmpty
    }

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        formatter.isLenient = false
        return formatter
    }
}

struct CurrencyAmountEditingState {
    private(set) var text: String
    let formatter: CurrencyAmountEditingFormatter

    init(value: Decimal, locale: Locale = .current) {
        formatter = CurrencyAmountEditingFormatter(locale: locale)
        text = formatter.string(from: value)
    }

    mutating func userEdited(
        _ newText: String,
        currentValue: Decimal
    ) -> CurrencyAmountEditResult {
        guard formatter.isValidEditingText(newText),
              let newValue = formatter.decimal(from: newText) else {
            return .invalid
        }

        text = newText
        guard newValue != currentValue else {
            return .unchanged
        }

        return .changed(newValue)
    }

    @discardableResult
    mutating func applyUserEdit(
        _ newText: String,
        currentValue: Decimal,
        updateValue: (Decimal) -> Void
    ) -> CurrencyAmountEditResult {
        let result = userEdited(newText, currentValue: currentValue)
        if case let .changed(newValue) = result {
            updateValue(newValue)
        }
        return result
    }

    mutating func synchronize(with externalValue: Decimal) {
        guard formatter.decimal(from: text) != externalValue else { return }
        text = formatter.string(from: externalValue)
    }
}

enum CurrencyAmountEditResult: Equatable {
    case invalid
    case unchanged
    case changed(Decimal)
}
