import Foundation

protocol FXRatesServicing: Sendable {
    func latestRates(for baseCurrency: Currency) async throws -> [FXRate]
}
