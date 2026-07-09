import Foundation

struct FXRate: Equatable, Sendable {
    let baseCurrency: Currency
    let quoteCurrency: Currency
    let rate: Decimal

    init(baseCurrency: Currency, quoteCurrency: Currency, rate: Decimal) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.rate = rate
    }
}
