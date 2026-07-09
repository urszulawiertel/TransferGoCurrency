import Foundation

public struct FXRate: Equatable, Sendable {
    public let baseCurrency: Currency
    public let quoteCurrency: Currency
    public let rate: Decimal

    public init(baseCurrency: Currency, quoteCurrency: Currency, rate: Decimal) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.rate = rate
    }
}

