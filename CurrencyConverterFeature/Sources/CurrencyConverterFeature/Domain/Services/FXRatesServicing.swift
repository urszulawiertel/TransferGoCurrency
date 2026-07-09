import Foundation

public protocol FXRatesServicing: Sendable {
    func latestRates(for baseCurrency: Currency) async throws -> [FXRate]
}

