import Foundation

final class URLSessionFXRatesService: FXRatesServicing {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func latestRates(for baseCurrency: Currency) async throws -> [FXRate] {
        _ = baseCurrency
        _ = urlSession
        return []
    }
}
