import XCTest
@testable import CurrencyConverterFeature

@MainActor
final class CurrencyConverterViewModelTests: XCTestCase {
    func testInitialState() {
        let viewModel = CurrencyConverterViewModel(
            fxRatesService: MockFXRatesService()
        )

        XCTAssertEqual(viewModel.fromCurrency, Currency(code: "PLN"))
        XCTAssertEqual(viewModel.toCurrency, Currency(code: "UAH"))
        XCTAssertEqual(viewModel.amount, 300)
        XCTAssertEqual(viewModel.convertedAmount, 0)
        XCTAssertNil(viewModel.conversionRate)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorState)
    }

    func testLoadFetchesInitialConversionAndStoresDirectRate() async throws {
        let service = MockFXRatesService { request in
            XCTAssertEqual(request, .init(from: "PLN", to: "UAH", amount: 300))
            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: 3_000
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.convertedAmount, 3_000)
        XCTAssertEqual(viewModel.conversionRate, 10)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorState)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 300)])
    }

    func testLoadFetchesOnlyOnce() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        await viewModel.load()
        await viewModel.load()

        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 300)])
    }

    func testAmountChangeFetchesConversionAndUpdatesConvertedAmount() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 12,
                fromAmount: request.amount,
                toAmount: request.amount * 12
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 400
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.convertedAmount, 4_800)
        XCTAssertEqual(viewModel.conversionRate, 12)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 400)])
    }

    func testConvertedAmountChangeFetchesReverseConversionAndStoresDisplayedRate() async throws {
        let service = MockFXRatesService { request in
            XCTAssertEqual(request, .init(from: "UAH", to: "PLN", amount: 1_500))
            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 0.1,
                fromAmount: request.amount,
                toAmount: 150
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = 1_500
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 150)
        XCTAssertEqual(viewModel.conversionRate, 10)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "UAH", to: "PLN", amount: 1_500)])
    }

    func testConvertedAmountChangeWithZeroReverseRateClearsDisplayedRate() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 0,
                fromAmount: request.amount,
                toAmount: 150
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = 1_500
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 150)
        XCTAssertNil(viewModel.conversionRate)
    }

    func testChangingFromCurrencyTriggersFreshRequest() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.fromCurrency = Currency(code: "EUR")
        await waitForIdle(viewModel)

        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "EUR", to: "UAH", amount: 300)])
    }

    func testChangingToCurrencyTriggersFreshRequest() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)

        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "GBP", amount: 300)])
    }

    func testApplyingConversionResultDoesNotCreateUpdateLoop() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 2,
                fromAmount: request.amount,
                toAmount: request.amount * 2
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 350
        await waitForIdle(viewModel)

        let requests = await service.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(viewModel.convertedAmount, 700)
    }

    func testSendingLimitExceededSetsErrorAndDoesNotFetchConversion() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 20_000.01
        await waitForIdle(viewModel)

        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        XCTAssertFalse(viewModel.isLoading)
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testCorrectingAmountAfterLimitErrorClearsError() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 20_000.01
        viewModel.amount = 20_000
        await waitForIdle(viewModel)

        XCTAssertNil(viewModel.errorState)
        XCTAssertEqual(viewModel.convertedAmount, 200_000)
        XCTAssertEqual(viewModel.conversionRate, 10)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 20_000)])
    }

    func testZeroAmountDoesNotCallAPIOrShowLimitError() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForIdle(viewModel)
        await service.removeAllRequests()

        viewModel.amount = 0
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.convertedAmount, 0)
        XCTAssertNil(viewModel.conversionRate)
        XCTAssertNil(viewModel.errorState)
        XCTAssertFalse(viewModel.isLoading)
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testNegativeAmountDoesNotCallAPIOrShowLimitError() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForIdle(viewModel)
        await service.removeAllRequests()

        viewModel.amount = -1
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.convertedAmount, 0)
        XCTAssertNil(viewModel.conversionRate)
        XCTAssertNil(viewModel.errorState)
        XCTAssertFalse(viewModel.isLoading)
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testZeroConvertedAmountDoesNotCallAPIOrShowLimitError() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = 0
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 0)
        XCTAssertNil(viewModel.conversionRate)
        XCTAssertNil(viewModel.errorState)
        XCTAssertFalse(viewModel.isLoading)
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testNegativeConvertedAmountDoesNotCallAPIOrShowLimitError() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = -1
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 0)
        XCTAssertEqual(viewModel.convertedAmount, -1)
        XCTAssertNil(viewModel.conversionRate)
        XCTAssertNil(viewModel.errorState)
        XCTAssertFalse(viewModel.isLoading)
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testReverseConversionValidatesResultingSendingAmount() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 1,
                fromAmount: request.amount,
                toAmount: 20_000.01
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = 20_000.01
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 20_000.01)
        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "UAH", to: "PLN", amount: 20_000.01)])
    }

    func testSwapCurrenciesSwapsAmountsAndFetchesConversion() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 0.08,
                fromAmount: request.amount,
                toAmount: 24
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)
        viewModel.convertedAmount = 3_000
        await waitForIdle(viewModel)

        await service.removeAllRequests()
        viewModel.swapCurrencies()
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.fromCurrency, Currency(code: "UAH"))
        XCTAssertEqual(viewModel.toCurrency, Currency(code: "PLN"))
        XCTAssertEqual(viewModel.amount, 3_000)
        XCTAssertEqual(viewModel.convertedAmount, 24)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "UAH", to: "PLN", amount: 3_000)])
    }

    func testLoadingStateIsExposedWhileConversionIsInFlight() async throws {
        let service = MockFXRatesService { request in
            try await Task.sleep(nanoseconds: 50_000_000)
            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301

        XCTAssertTrue(viewModel.isLoading)
        await waitForIdle(viewModel)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.convertedAmount, 3_010)
    }

    func testServiceFailureExposesErrorState() async throws {
        let service = MockFXRatesService { _ in
            throw URLError(.notConnectedToInternet)
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.errorState, .conversionFailed)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testOnlyLatestConversionResultIsApplied() async throws {
        let service = MockFXRatesService { request in
            if request.amount == 301 {
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForRequests(count: 1, service: service)
        viewModel.amount = 302
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.convertedAmount, 3_020)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests.map(\.amount), [301, 302])
    }

    private func waitForIdle(
        _ viewModel: CurrencyConverterViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if !viewModel.isLoading {
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for conversion to finish.", file: file, line: line)
    }

    private func waitForRequests(
        count: Int,
        service: MockFXRatesService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            let requests = await service.recordedRequests()

            if requests.count >= count {
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for service request.", file: file, line: line)
    }
}

private actor MockFXRatesService: FXRatesServicing {
    struct Request: Equatable {
        let fromCurrency: Currency
        let toCurrency: Currency
        let amount: Decimal

        init(fromCurrency: Currency, toCurrency: Currency, amount: Decimal) {
            self.fromCurrency = fromCurrency
            self.toCurrency = toCurrency
            self.amount = amount
        }

        init(from: String, to: String, amount: Decimal) {
            self.init(
                fromCurrency: Currency(code: from),
                toCurrency: Currency(code: to),
                amount: amount
            )
        }
    }

    private let handler: @Sendable (Request) async throws -> FXRate
    private(set) var requests: [Request] = []

    init(handler: @escaping @Sendable (Request) async throws -> FXRate = defaultHandler) {
        self.handler = handler
    }

    func rate(from sourceCurrency: Currency, to targetCurrency: Currency, amount: Decimal) async throws -> FXRate {
        let request = Request(
            fromCurrency: sourceCurrency,
            toCurrency: targetCurrency,
            amount: amount
        )
        requests.append(request)
        return try await handler(request)
    }

    func removeAllRequests() {
        requests.removeAll()
    }

    func recordedRequests() -> [Request] {
        requests
    }

    private static let defaultHandler: @Sendable (Request) async throws -> FXRate = { request in
        FXRate(
            fromCurrency: request.fromCurrency,
            toCurrency: request.toCurrency,
            rate: 1,
            fromAmount: request.amount,
            toAmount: request.amount
        )
    }
}
