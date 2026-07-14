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

extension FXRate {
    func displayedRate(
        from sourceCurrency: Currency,
        to targetCurrency: Currency
    ) -> Decimal? {
        if fromCurrency == sourceCurrency,
           toCurrency == targetCurrency {
            return rate
        }

        guard fromCurrency == targetCurrency,
              toCurrency == sourceCurrency,
              rate != 0 else {
            return nil
        }

        return 1 / rate
    }
}
