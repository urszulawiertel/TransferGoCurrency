import Foundation

public struct FXRate: Equatable, Sendable {
    let fromCurrency: Currency
    let toCurrency: Currency
    let rate: Decimal
    let fromAmount: Decimal
    let toAmount: Decimal

    init(
        fromCurrency: Currency,
        toCurrency: Currency,
        rate: Decimal,
        fromAmount: Decimal,
        toAmount: Decimal
    ) {
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
        self.rate = rate
        self.fromAmount = fromAmount
        self.toAmount = toAmount
    }
}
