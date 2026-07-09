import Foundation

struct CurrencyLimitValidator: Sendable {
    private let limits: [Currency: Decimal]

    init(supportedCurrencies: [SupportedCurrency] = SupportedCurrency.all) {
        limits = Dictionary(
            uniqueKeysWithValues: supportedCurrencies.map { ($0.currency, $0.sendingLimit) }
        )
    }

    func limit(for currency: Currency) -> Decimal? {
        limits[currency]
    }

    func canSend(amount: Decimal, currency: Currency) -> Bool {
        guard let limit = limits[currency] else {
            return false
        }

        return amount > 0 && amount <= limit
    }
}
