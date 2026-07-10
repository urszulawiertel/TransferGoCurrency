import Foundation

extension Decimal {
    func currencyConverterFormatted(
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.locale = .current

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
