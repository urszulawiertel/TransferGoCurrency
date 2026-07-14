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

    func testRepeatedLoadAfterSuccessDoesNotFetchAgain() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        await viewModel.load()
        await viewModel.load()

        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 300)])
    }

    func testFailedInitialLoadExposesNetworkErrorWithoutConversionData() async throws {
        let service = MockFXRatesService { _ in
            throw URLError(.notConnectedToInternet)
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.errorState, .networkError)
        XCTAssertTrue(viewModel.isNetworkErrorVisible)
        XCTAssertNil(viewModel.conversionRate)
        XCTAssertEqual(viewModel.convertedAmount, 0)
        XCTAssertFalse(viewModel.isLoading)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 300)])
    }

    func testFailedInitialLoadCanBeRetriedSuccessfully() async throws {
        let wrappedService = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let service = FailFirstRequestFXRatesService(wrapping: wrappedService)
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        await viewModel.load()
        XCTAssertEqual(viewModel.errorState, .networkError)

        await viewModel.load()

        XCTAssertNil(viewModel.errorState)
        XCTAssertEqual(viewModel.conversionRate, 10)
        XCTAssertEqual(viewModel.convertedAmount, 3_000)
        let attemptedRequests = await service.attemptedRequestCount()
        XCTAssertEqual(attemptedRequests, 2)
        let successfulRequests = await wrappedService.recordedRequests()
        XCTAssertEqual(successfulRequests, [.init(from: "PLN", to: "UAH", amount: 300)])
    }

    func testRequestsUseRegularServiceNormallyWithoutSimulation() async throws {
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

        await viewModel.load()
        viewModel.amount = 301
        await waitForIdle(viewModel)
        viewModel.amount = 302
        await waitForIdle(viewModel)

        XCTAssertNil(viewModel.errorState)
        XCTAssertEqual(viewModel.conversionRate, 10)
        XCTAssertEqual(viewModel.convertedAmount, 3_020)
        let requests = await service.recordedRequests()
        XCTAssertEqual(
            requests,
            [
                .init(from: "PLN", to: "UAH", amount: 300),
                .init(from: "PLN", to: "UAH", amount: 301),
                .init(from: "PLN", to: "UAH", amount: 302)
            ]
        )
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

    func testFractionalSendingAmountPreservesLastSuccessfulConversionUntilCorrectionSucceeds() async throws {
        let service = MockFXRatesService { request in
            let rate: Decimal = request.amount == 400 ? 2 : 3
            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: rate,
                fromAmount: request.amount,
                toAmount: request.amount * rate
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 400
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.convertedAmount, 800)
        XCTAssertEqual(viewModel.conversionRate, 2)
        await service.removeAllRequests()

        viewModel.amount = try XCTUnwrap(Decimal(string: "400.5"))
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, try XCTUnwrap(Decimal(string: "400.5")))
        XCTAssertEqual(viewModel.convertedAmount, 800)
        XCTAssertEqual(viewModel.conversionRate, 2)
        XCTAssertEqual(viewModel.errorState, .fractionalAmountNotSupported)
        XCTAssertEqual(viewModel.errorState?.message, "Only whole amounts are supported")
        XCTAssertFalse(viewModel.isLoading)
        var requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)

        viewModel.amount = 401

        XCTAssertNil(viewModel.errorState)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(viewModel.convertedAmount, 800)
        XCTAssertEqual(viewModel.conversionRate, 2)

        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.convertedAmount, 1_203)
        XCTAssertEqual(viewModel.conversionRate, 3)
        requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 401)])
    }

    func testFractionalReceivingAmountPreservesLastSuccessfulConversionUntilCorrectionSucceeds() async throws {
        let service = MockFXRatesService { request in
            let rate: Decimal = request.amount == 800 ? 2 : 4
            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: rate,
                fromAmount: request.amount,
                toAmount: request.amount * rate
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = 800
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.amount, 1_600)
        XCTAssertEqual(viewModel.conversionRate, Decimal(string: "0.5"))
        await service.removeAllRequests()

        viewModel.convertedAmount = try XCTUnwrap(Decimal(string: "800.5"))
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.convertedAmount, try XCTUnwrap(Decimal(string: "800.5")))
        XCTAssertEqual(viewModel.amount, 1_600)
        XCTAssertEqual(viewModel.conversionRate, Decimal(string: "0.5"))
        XCTAssertEqual(viewModel.errorState, .fractionalAmountNotSupported)
        XCTAssertFalse(viewModel.isLoading)
        var requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)

        viewModel.convertedAmount = 801

        XCTAssertNil(viewModel.errorState)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(viewModel.amount, 1_600)
        XCTAssertEqual(viewModel.conversionRate, Decimal(string: "0.5"))

        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 3_204)
        XCTAssertEqual(viewModel.conversionRate, Decimal(string: "0.25"))
        requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "UAH", to: "PLN", amount: 801)])
    }

    func testFractionalSendingAmountAboveLimitDoesNotOverwriteSendingLimitError() async throws {
        let service = MockFXRatesService()
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 20_001
        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )

        viewModel.amount = try XCTUnwrap(Decimal(string: "20000.5"))
        await waitForIdle(viewModel)

        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testIntegerEditingKeepsDisplayedAndRequestedAmountsIdenticalAcrossLocales() async throws {
        for locale in [Locale(identifier: "en_US"), Locale(identifier: "pl_PL")] {
            for direction in AmountEditingDirection.allCases {
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
                let currentValue = direction == .sending ? viewModel.amount : viewModel.convertedAmount
                var editingState = CurrencyAmountEditingState(value: currentValue, locale: locale)

                let result = editingState.applyUserEdit("1000", currentValue: currentValue) { value in
                    switch direction {
                    case .sending:
                        viewModel.amount = value
                    case .receiving:
                        viewModel.convertedAmount = value
                    }
                }
                await waitForIdle(viewModel)

                XCTAssertEqual(result, .changed(1_000))
                XCTAssertEqual(editingState.text, "1000")
                XCTAssertNil(viewModel.errorState)
                let requests = await service.recordedRequests()
                XCTAssertEqual(requests.map(\.amount), [1_000])
            }
        }
    }

    func testFractionalValidationRuleIsSameForEnglishAndPolishLocales() async throws {
        let localizedInputs: [(Locale, [String])] = [
            (Locale(identifier: "en_US"), ["1.01", "1.5", "1.99", "10.50", "999.99", "1000.5"]),
            (Locale(identifier: "pl_PL"), ["1,01", "1,5", "1,99", "10,50", "999,99", "1000,5"])
        ]

        for (locale, texts) in localizedInputs {
            for text in texts {
                for direction in AmountEditingDirection.allCases {
                    let service = MockFXRatesService()
                    let viewModel = CurrencyConverterViewModel(fxRatesService: service)
                    let currentValue = direction == .sending ? viewModel.amount : viewModel.convertedAmount
                    var editingState = CurrencyAmountEditingState(value: currentValue, locale: locale)

                    let result = editingState.applyUserEdit(text, currentValue: currentValue) { value in
                        switch direction {
                        case .sending:
                            viewModel.amount = value
                        case .receiving:
                            viewModel.convertedAmount = value
                        }
                    }
                    await waitForIdle(viewModel)

                    let normalizedText = text.replacingOccurrences(of: ",", with: ".")
                    XCTAssertEqual(result, .changed(try XCTUnwrap(Decimal(string: normalizedText))))
                    XCTAssertEqual(editingState.text, text)
                    XCTAssertEqual(viewModel.errorState, .fractionalAmountNotSupported)
                    let requests = await service.recordedRequests()
                    XCTAssertTrue(requests.isEmpty)
                }
            }
        }
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

    func testChangingFromCurrencyWhileLimitExceededFetchesAndAppliesNewPair() async throws {
        let exceededAmount = try XCTUnwrap(Decimal(string: "20001"))
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

        viewModel.amount = exceededAmount
        viewModel.fromCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)

        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "GBP"), limit: 1_000)
        )
        XCTAssertEqual(viewModel.conversionRate, 2)
        XCTAssertEqual(viewModel.convertedAmount, exceededAmount * 2)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "GBP", to: "UAH", amount: exceededAmount)])
    }

    func testChangingToCurrencyWhileLimitExceededFetchesAndKeepsSendingLimitError() async throws {
        let exceededAmount = try XCTUnwrap(Decimal(string: "20001"))
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 3,
                fromAmount: request.amount,
                toAmount: request.amount * 3
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = exceededAmount
        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)

        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        XCTAssertEqual(viewModel.conversionRate, 3)
        XCTAssertEqual(viewModel.convertedAmount, exceededAmount * 3)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "GBP", amount: exceededAmount)])
    }

    func testFailedCurrencyChangeWhileLimitExceededKeepsValidationAndClearsOldPairData() async throws {
        let exceededAmount = try XCTUnwrap(Decimal(string: "20001"))
        let service = MockFXRatesService { request in
            if request.toCurrency == Currency(code: "GBP") {
                throw URLError(.notConnectedToInternet)
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

        viewModel.amount = 1_000
        await waitForIdle(viewModel)
        viewModel.amount = exceededAmount
        await service.removeAllRequests()

        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)

        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        XCTAssertFalse(viewModel.isNetworkErrorVisible)
        XCTAssertNil(viewModel.conversionRate)
        XCTAssertEqual(viewModel.convertedAmount, 0)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "GBP", amount: exceededAmount)])
    }

    func testCurrencyChangeResultDoesNotTriggerSecondRequest() async throws {
        let exceededAmount = try XCTUnwrap(Decimal(string: "20001"))
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

        viewModel.amount = exceededAmount
        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)

        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "GBP", amount: exceededAmount)])
        XCTAssertEqual(viewModel.convertedAmount, exceededAmount * 2)
    }

    func testChangingCurrencyClearsPreviousPairsRateUntilNewRateArrives() async throws {
        let service = MockFXRatesService { request in
            if request.fromCurrency == Currency(code: "EUR") {
                try await Task.sleep(nanoseconds: 50_000_000)
            }

            let rate: Decimal = request.fromCurrency == Currency(code: "EUR") ? 12 : 10
            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: rate,
                fromAmount: request.amount,
                toAmount: request.amount * rate
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.conversionRate, 10)

        viewModel.fromCurrency = Currency(code: "EUR")

        XCTAssertNil(viewModel.conversionRate)
        XCTAssertTrue(viewModel.isLoading)

        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.conversionRate, 12)
    }

    func testChangingCurrencyAtZeroFetchesReferenceRateWithoutChangingAmounts() async throws {
        let service = MockFXRatesService { request in
            let rate: Decimal = request.toCurrency == Currency(code: "GBP") ? 12 : 10
            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: rate,
                fromAmount: request.amount,
                toAmount: request.amount * rate
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.conversionRate, 10)

        viewModel.amount = 0
        await service.removeAllRequests()
        viewModel.toCurrency = Currency(code: "GBP")

        XCTAssertNil(viewModel.conversionRate)
        XCTAssertEqual(viewModel.amount, 0)
        XCTAssertEqual(viewModel.convertedAmount, 0)

        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 0)
        XCTAssertEqual(viewModel.convertedAmount, 0)
        XCTAssertEqual(viewModel.conversionRate, 12)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "GBP", amount: 1)])
    }

    func testStaleReferenceRateFromPreviousPairIsIgnored() async throws {
        let service = MockFXRatesService { request in
            switch request.toCurrency.code {
            case "GBP":
                try? await Task.sleep(nanoseconds: 100_000_000)
                return FXRate(
                    fromCurrency: request.fromCurrency,
                    toCurrency: request.toCurrency,
                    rate: 20,
                    fromAmount: request.amount,
                    toAmount: 20
                )
            case "EUR":
                try await Task.sleep(nanoseconds: 10_000_000)
                return FXRate(
                    fromCurrency: request.fromCurrency,
                    toCurrency: request.toCurrency,
                    rate: 30,
                    fromAmount: request.amount,
                    toAmount: 30
                )
            default:
                return FXRate(
                    fromCurrency: request.fromCurrency,
                    toCurrency: request.toCurrency,
                    rate: 10,
                    fromAmount: request.amount,
                    toAmount: request.amount * 10
                )
            }
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 0
        viewModel.toCurrency = Currency(code: "GBP")
        await waitForRequests(count: 1, service: service)
        viewModel.toCurrency = Currency(code: "EUR")
        await waitForIdle(viewModel)
        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(viewModel.amount, 0)
        XCTAssertEqual(viewModel.convertedAmount, 0)
        XCTAssertEqual(viewModel.conversionRate, 30)
        let requests = await service.recordedRequests()
        XCTAssertEqual(
            requests,
            [
                .init(from: "PLN", to: "GBP", amount: 1),
                .init(from: "PLN", to: "EUR", amount: 1)
            ]
        )
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

    func testSendingLimitExceededPreservesLastSuccessfulConversionAndDoesNotFetchAgain() async throws {
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

        viewModel.amount = 1_000
        await waitForIdle(viewModel)
        await service.removeAllRequests()

        viewModel.amount = 20_001
        await waitForIdle(viewModel)

        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.convertedAmount, 10_000)
        XCTAssertEqual(viewModel.conversionRate, 10)
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

        viewModel.amount = 20_001
        viewModel.amount = 20_000
        await waitForIdle(viewModel)

        XCTAssertNil(viewModel.errorState)
        XCTAssertEqual(viewModel.convertedAmount, 200_000)
        XCTAssertEqual(viewModel.conversionRate, 10)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 20_000)])
    }

    func testZeroAmountResetsCalculatedAmountAndPreservesCurrentPairsRate() async throws {
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
        XCTAssertEqual(viewModel.conversionRate, 10)
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

    func testZeroConvertedAmountResetsCalculatedAmountAndPreservesCurrentPairsRate() async throws {
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: Decimal(string: "0.1")!,
                fromAmount: request.amount,
                toAmount: request.amount / 10
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = 1_500
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.amount, 150)
        XCTAssertEqual(viewModel.conversionRate, 10)
        await service.removeAllRequests()

        viewModel.convertedAmount = 0
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 0)
        XCTAssertEqual(viewModel.conversionRate, 10)
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
                toAmount: 20_001
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.convertedAmount = 20_001
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 20_001)
        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "UAH", to: "PLN", amount: 20_001)])
    }

    func testSwapPreservesFractionalConversionWithoutRequestOrValidationAndReversesRate() async throws {
        let backendRate = try XCTUnwrap(Decimal(string: "0.0205685"))
        let fractionalConvertedAmount = try XCTUnwrap(Decimal(string: "411.37"))
        let service = MockFXRatesService { request in
            if request == .init(from: "UAH", to: "GBP", amount: 20_000) {
                return FXRate(
                    fromCurrency: request.fromCurrency,
                    toCurrency: request.toCurrency,
                    rate: backendRate,
                    fromAmount: request.amount,
                    toAmount: fractionalConvertedAmount
                )
            }

            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 1,
                fromAmount: request.amount,
                toAmount: request.amount
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)
        viewModel.fromCurrency = Currency(code: "UAH")
        await waitForIdle(viewModel)
        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)
        await service.removeAllRequests()

        viewModel.amount = 20_000
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 20_000)
        XCTAssertEqual(viewModel.convertedAmount, fractionalConvertedAmount)
        XCTAssertEqual(viewModel.conversionRate, backendRate)
        XCTAssertNil(viewModel.errorState)

        await service.removeAllRequests()
        viewModel.swapCurrencies()

        XCTAssertEqual(viewModel.fromCurrency, Currency(code: "GBP"))
        XCTAssertEqual(viewModel.toCurrency, Currency(code: "UAH"))
        XCTAssertEqual(viewModel.amount, fractionalConvertedAmount)
        XCTAssertEqual(viewModel.convertedAmount, 20_000)
        XCTAssertNotEqual(viewModel.amount, 0)
        XCTAssertNotEqual(viewModel.convertedAmount, 0)
        XCTAssertEqual(viewModel.conversionRate, 1 / backendRate)
        XCTAssertEqual(
            viewModel.conversionRate?.currencyConverterFormatted(
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
                locale: Locale(identifier: "en_US")
            ),
            "48.62"
        )
        XCTAssertNil(viewModel.errorState)
        XCTAssertFalse(viewModel.isLoading)
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testEditingSwappedSourceWithWholeAmountFetchesForSwappedPair() async throws {
        let fractionalConvertedAmount = try XCTUnwrap(Decimal(string: "411.37"))
        let service = MockFXRatesService { request in
            if request == .init(from: "UAH", to: "GBP", amount: 20_000) {
                return FXRate(
                    fromCurrency: request.fromCurrency,
                    toCurrency: request.toCurrency,
                    rate: Decimal(string: "0.0205685")!,
                    fromAmount: request.amount,
                    toAmount: fractionalConvertedAmount
                )
            }

            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: Decimal(string: "48.5")!,
                fromAmount: request.amount,
                toAmount: 19_982
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)
        viewModel.fromCurrency = Currency(code: "UAH")
        await waitForIdle(viewModel)
        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)
        viewModel.amount = 20_000
        await waitForIdle(viewModel)
        viewModel.swapCurrencies()
        await service.removeAllRequests()

        viewModel.amount = 412
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.amount, 412)
        XCTAssertEqual(viewModel.convertedAmount, 19_982)
        XCTAssertEqual(viewModel.conversionRate, Decimal(string: "48.5"))
        XCTAssertNil(viewModel.errorState)
        let requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "GBP", to: "UAH", amount: 412)])
    }

    func testFractionalSwappedSourcePreservesTypedTextAndLastConversionUntilWholeCorrection() async throws {
        let backendRate = try XCTUnwrap(Decimal(string: "0.0205685"))
        let fractionalConvertedAmount = try XCTUnwrap(Decimal(string: "411.37"))
        let service = MockFXRatesService { request in
            if request == .init(from: "UAH", to: "GBP", amount: 20_000) {
                return FXRate(
                    fromCurrency: request.fromCurrency,
                    toCurrency: request.toCurrency,
                    rate: backendRate,
                    fromAmount: request.amount,
                    toAmount: fractionalConvertedAmount
                )
            }

            return FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: Decimal(string: "48.5")!,
                fromAmount: request.amount,
                toAmount: 19_982
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)
        viewModel.fromCurrency = Currency(code: "UAH")
        await waitForIdle(viewModel)
        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)
        viewModel.amount = 20_000
        await waitForIdle(viewModel)
        viewModel.swapCurrencies()
        await service.removeAllRequests()
        let swappedRate = try XCTUnwrap(viewModel.conversionRate)
        var editingState = CurrencyAmountEditingState(
            value: viewModel.amount,
            locale: Locale(identifier: "en_US")
        )

        let editResult = editingState.applyUserEdit(
            "411.50",
            currentValue: viewModel.amount
        ) { viewModel.amount = $0 }
        await waitForIdle(viewModel)

        XCTAssertEqual(editResult, .changed(Decimal(string: "411.5")!))
        XCTAssertEqual(editingState.text, "411.50")
        XCTAssertEqual(viewModel.amount, Decimal(string: "411.5"))
        XCTAssertEqual(viewModel.convertedAmount, 20_000)
        XCTAssertEqual(viewModel.conversionRate, swappedRate)
        XCTAssertEqual(viewModel.errorState, .fractionalAmountNotSupported)
        XCTAssertEqual(viewModel.errorState?.message, "Only whole amounts are supported")
        var requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)

        viewModel.amount = 412

        XCTAssertNil(viewModel.errorState)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(viewModel.convertedAmount, 20_000)
        XCTAssertEqual(viewModel.conversionRate, swappedRate)

        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.convertedAmount, 19_982)
        XCTAssertEqual(viewModel.conversionRate, Decimal(string: "48.5"))
        XCTAssertNil(viewModel.errorState)
        requests = await service.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "GBP", to: "UAH", amount: 412)])
    }

    func testRepeatedSwapsRestoreOriginalConversionWithoutRateRoundingAccumulation() async throws {
        let backendRate = try XCTUnwrap(Decimal(string: "0.0205685"))
        let fractionalConvertedAmount = try XCTUnwrap(Decimal(string: "411.37"))
        let service = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: backendRate,
                fromAmount: request.amount,
                toAmount: fractionalConvertedAmount
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)
        viewModel.fromCurrency = Currency(code: "UAH")
        await waitForIdle(viewModel)
        viewModel.toCurrency = Currency(code: "GBP")
        await waitForIdle(viewModel)
        viewModel.amount = 20_000
        await waitForIdle(viewModel)
        await service.removeAllRequests()

        for _ in 0..<10 {
            viewModel.swapCurrencies()
            viewModel.swapCurrencies()
        }

        XCTAssertEqual(viewModel.fromCurrency, Currency(code: "UAH"))
        XCTAssertEqual(viewModel.toCurrency, Currency(code: "GBP"))
        XCTAssertEqual(viewModel.amount, 20_000)
        XCTAssertEqual(viewModel.convertedAmount, fractionalConvertedAmount)
        XCTAssertEqual(viewModel.conversionRate, backendRate)
        XCTAssertNil(viewModel.errorState)
        let requests = await service.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
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

    func testConnectivityFailuresExposeNetworkErrorState() async throws {
        for code in [
            URLError.notConnectedToInternet,
            .networkConnectionLost
        ] {
            let service = MockFXRatesService { _ in
                throw URLError(code)
            }
            let viewModel = CurrencyConverterViewModel(fxRatesService: service)

            viewModel.amount = 301
            await waitForIdle(viewModel)

            XCTAssertEqual(viewModel.errorState, .networkError, "Failed for URL error code: \(code)")
            XCTAssertTrue(viewModel.isNetworkErrorVisible)
            XCTAssertFalse(viewModel.isLoading)
        }
    }

#if DEBUG
    func testSimulatedFailurePreservesConversionAndDismissDoesNotRetry() async throws {
        let wrappedService = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let service = SimulatedNetworkErrorFXRatesService(wrapping: wrappedService)
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        await viewModel.load()
        XCTAssertNil(viewModel.errorState)
        XCTAssertEqual(viewModel.conversionRate, 10)
        XCTAssertEqual(viewModel.convertedAmount, 3_000)

        viewModel.amount = 301
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.errorState, .networkError)
        XCTAssertEqual(viewModel.conversionRate, 10)
        XCTAssertEqual(viewModel.convertedAmount, 3_000)

        viewModel.dismissNetworkError()

        XCTAssertNil(viewModel.errorState)
        XCTAssertFalse(viewModel.isNetworkErrorVisible)
        var requests = await wrappedService.recordedRequests()
        XCTAssertEqual(requests, [.init(from: "PLN", to: "UAH", amount: 300)])

        viewModel.amount = 302
        await waitForIdle(viewModel)

        XCTAssertNil(viewModel.errorState)
        XCTAssertEqual(viewModel.conversionRate, 10)
        XCTAssertEqual(viewModel.convertedAmount, 3_020)
        requests = await wrappedService.recordedRequests()
        XCTAssertEqual(
            requests,
            [
                .init(from: "PLN", to: "UAH", amount: 300),
                .init(from: "PLN", to: "UAH", amount: 302)
            ]
        )
    }

    func testDebugNetworkErrorSimulationSucceedsThenFailsOnceThenSucceeds() async throws {
        let wrappedService = MockFXRatesService { request in
            FXRate(
                fromCurrency: request.fromCurrency,
                toCurrency: request.toCurrency,
                rate: 10,
                fromAmount: request.amount,
                toAmount: request.amount * 10
            )
        }
        let service = SimulatedNetworkErrorFXRatesService(wrapping: wrappedService)
        let sourceCurrency = Currency(code: "PLN")
        let targetCurrency = Currency(code: "UAH")

        let firstRate = try await service.rate(
            from: sourceCurrency,
            to: targetCurrency,
            amount: 300
        )

        XCTAssertEqual(firstRate.rate, 10)
        XCTAssertEqual(firstRate.toAmount, 3_000)

        do {
            _ = try await service.rate(
                from: sourceCurrency,
                to: targetCurrency,
                amount: 301
            )
            XCTFail("Expected the second request to simulate a network error.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }

        let thirdRate = try await service.rate(
            from: sourceCurrency,
            to: targetCurrency,
            amount: 302
        )

        XCTAssertEqual(thirdRate.rate, 10)
        XCTAssertEqual(thirdRate.toAmount, 3_020)
        let requests = await wrappedService.recordedRequests()
        XCTAssertEqual(
            requests,
            [
                .init(from: "PLN", to: "UAH", amount: 300),
                .init(from: "PLN", to: "UAH", amount: 302)
            ]
        )
    }
#endif

    func testSuccessfulRequestAfterConnectivityFailureClearsNetworkError() async throws {
        let service = MockFXRatesService { request in
            if request.amount == 301 {
                throw URLError(.networkConnectionLost)
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
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.errorState, .networkError)

        viewModel.amount = 302
        XCTAssertEqual(viewModel.errorState, .networkError)
        await waitForIdle(viewModel)

        XCTAssertNil(viewModel.errorState)
        XCTAssertEqual(viewModel.convertedAmount, 3_020)
        XCTAssertEqual(viewModel.conversionRate, 10)
    }

    func testNonConnectivityServiceFailureDoesNotExposeNetworkError() async throws {
        let service = MockFXRatesService { _ in
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Invalid response")
            )
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.errorState, .conversionFailed)
        XCTAssertFalse(viewModel.isNetworkErrorVisible)
    }

    func testTimedOutFailureKeepsExistingGenericErrorMapping() async throws {
        let service = MockFXRatesService { _ in
            throw URLError(.timedOut)
        }
        let viewModel = CurrencyConverterViewModel(fxRatesService: service)

        viewModel.amount = 301
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.errorState, .conversionFailed)
        XCTAssertFalse(viewModel.isNetworkErrorVisible)
    }

    func testValidationAndSendingLimitErrorsDoNotExposeNetworkError() async throws {
        let viewModel = CurrencyConverterViewModel(
            fxRatesService: MockFXRatesService()
        )

        viewModel.amount = -1
        await waitForIdle(viewModel)
        XCTAssertNil(viewModel.errorState)
        XCTAssertFalse(viewModel.isNetworkErrorVisible)

        viewModel.amount = 20_001
        await waitForIdle(viewModel)
        XCTAssertEqual(
            viewModel.errorState,
            .sendingLimitExceeded(currency: Currency(code: "PLN"), limit: 20_000)
        )
        XCTAssertFalse(viewModel.isNetworkErrorVisible)
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

    private enum AmountEditingDirection: CaseIterable {
        case sending
        case receiving
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

private actor FailFirstRequestFXRatesService: FXRatesServicing {
    private let wrappedService: FXRatesServicing
    private var shouldFail = true
    private var attemptCount = 0

    init(wrapping wrappedService: FXRatesServicing) {
        self.wrappedService = wrappedService
    }

    func rate(
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        amount: Decimal
    ) async throws -> FXRate {
        attemptCount += 1

        if shouldFail {
            shouldFail = false
            throw URLError(.notConnectedToInternet)
        }

        return try await wrappedService.rate(
            from: sourceCurrency,
            to: targetCurrency,
            amount: amount
        )
    }

    func attemptedRequestCount() -> Int {
        attemptCount
    }
}
