import Foundation

public protocol FXRatesServicing: Sendable {
    func rate(from sourceCurrency: Currency, to targetCurrency: Currency, amount: Decimal) async throws -> FXRate
}
