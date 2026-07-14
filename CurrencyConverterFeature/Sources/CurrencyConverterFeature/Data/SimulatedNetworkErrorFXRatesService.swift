#if DEBUG
import Foundation

public actor SimulatedNetworkErrorFXRatesService: FXRatesServicing {
    private let wrappedService: FXRatesServicing
    private var successfulRequestCount = 0
    private var shouldFailNextEligibleRequest = false

    public init() {
        wrappedService = URLSessionFXRatesService()
    }

    init(wrapping wrappedService: FXRatesServicing) {
        self.wrappedService = wrappedService
    }

    public func rate(
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        amount: Decimal
    ) async throws -> FXRate {
        try Task.checkCancellation()

        if shouldFailNextEligibleRequest {
            shouldFailNextEligibleRequest = false
            throw URLError(.notConnectedToInternet)
        }

        let rate = try await wrappedService.rate(
            from: sourceCurrency,
            to: targetCurrency,
            amount: amount
        )
        try Task.checkCancellation()

        successfulRequestCount += 1
        if successfulRequestCount == 1 {
            shouldFailNextEligibleRequest = true
        }

        return rate
    }
}
#endif
