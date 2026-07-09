import Foundation

public final class URLSessionFXRatesService: FXRatesServicing {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func latestRates(for baseCurrency: Currency) async throws -> [FXRate] {
        _ = baseCurrency
        _ = urlSession
        return []
    }
}

