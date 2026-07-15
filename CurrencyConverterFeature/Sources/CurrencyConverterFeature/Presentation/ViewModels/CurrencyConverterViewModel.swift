import Combine
import Foundation

@MainActor
final class CurrencyConverterViewModel: ObservableObject {
    @Published var fromCurrency: Currency {
        didSet {
            currencyPairDidChange()
        }
    }

    @Published var toCurrency: Currency {
        didSet {
            currencyPairDidChange()
        }
    }

    @Published var amount: Decimal {
        didSet {
            fetchConversionIfNeeded(source: .sendingAmount)
        }
    }

    @Published var convertedAmount: Decimal {
        didSet {
            fetchConversionIfNeeded(source: .receivingAmount)
        }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorState: CurrencyConverterErrorState?
    @Published private(set) var conversionRate: Decimal?

    var isSendingLimitExceeded: Bool {
        guard case .sendingLimitExceeded = errorState else {
            return false
        }

        return true
    }

    var isNetworkErrorVisible: Bool {
        errorState == .networkError
    }

    private let fxRatesService: FXRatesServicing
    private let validator: CurrencyLimitValidator
    private var conversionTask: Task<Void, Never>?
    private var latestRequestID: UUID?
    private var latestBackendRate: FXRate?
    private var isApplyingConversionResult = false
    private var hasLoaded = false

    init(
        fxRatesService: FXRatesServicing = URLSessionFXRatesService(),
        validator: CurrencyLimitValidator = CurrencyLimitValidator()
    ) {
        self.fxRatesService = fxRatesService
        self.validator = validator
        fromCurrency = Currency(code: "PLN")
        toCurrency = Currency(code: "UAH")
        amount = 300
        convertedAmount = 0
    }

    deinit {
        conversionTask?.cancel()
    }

    func load() async {
        guard !hasLoaded else {
            return
        }

        if !isLoading {
            fetchConversionIfNeeded(source: .sendingAmount)
        }
        await conversionTask?.value
    }

    func swapCurrencies() {
        invalidatePendingRequest()
        isApplyingConversionResult = true

        let previousFromCurrency = fromCurrency
        fromCurrency = toCurrency
        toCurrency = previousFromCurrency

        let previousAmount = amount
        amount = convertedAmount
        convertedAmount = previousAmount

        conversionRate = latestBackendRate?.displayedRate(
            from: fromCurrency,
            to: toCurrency
        )
        isApplyingConversionResult = false

        startCurrencyPairConversion()
    }

    func dismissNetworkError() {
        guard errorState == .networkError else {
            return
        }

        errorState = nil
    }

    private func fetchConversionIfNeeded(source: ConversionSource) {
        guard !isApplyingConversionResult else {
            return
        }

        invalidatePendingRequest()

        let activeAmount = activeAmount(for: source)

        guard activeAmount != 0 else {
            clearConversionState(source: source)
            return
        }

        guard activeAmount > 0 else {
            isLoading = false
            errorState = nil
            clearStaleConversionData(source: source)
            return
        }

        if source == .sendingAmount, !updateSendingLimitValidation() {
            isLoading = false

            if !isSendingLimitExceeded {
                clearStaleConversionData(source: source)
            }

            return
        }

        isLoading = true
        clearNonNetworkError()

        start(makeConversionRequest(source: source, preservesSendingLimitError: false))
    }

    private func fetchConversion(_ request: ConversionRequest) async {
        do {
            let rate = try await fxRatesService.rate(
                from: request.fromCurrency,
                to: request.toCurrency,
                amount: request.amount
            )

            guard isCurrentRequest(request) else {
                return
            }

            guard rate.fromCurrency == request.fromCurrency,
                  rate.toCurrency == request.toCurrency,
                  rate.rate > 0 else {
                throw FXRatesServiceError.invalidResponse
            }

            switch request.purpose {
            case let .conversion(source):
                apply(
                    rate: rate,
                    requestedAmount: request.amount,
                    source: source,
                    preservesSendingLimitError: request.preservesSendingLimitError
                )
            case .referenceRate:
                storeLatestRate(rate)

                if !request.preservesSendingLimitError {
                    errorState = nil
                }
            }
            hasLoaded = true
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentRequest(request) else {
                return
            }

            if !request.preservesSendingLimitError || !isSendingLimitExceeded {
                errorState = CurrencyConverterErrorState(error: error)
            }
            isLoading = false
        }
    }

    private func apply(
        rate: FXRate,
        requestedAmount: Decimal,
        source: ConversionSource,
        preservesSendingLimitError: Bool
    ) {
        let exactCalculatedAmount = requestedAmount * rate.rate
        let calculatedAmount = exactCalculatedAmount.roundedForCurrencyDisplay()

        isApplyingConversionResult = true
        defer { isApplyingConversionResult = false }

        storeLatestRate(rate)

        if !preservesSendingLimitError {
            errorState = nil
        }

        switch source {
        case .sendingAmount:
            convertedAmount = calculatedAmount
        case .receivingAmount:
            amount = calculatedAmount

            guard let sendingLimit = validator.limit(for: fromCurrency) else {
                errorState = .conversionFailed
                return
            }

            if exactCalculatedAmount > sendingLimit {
                errorState = .sendingLimitExceeded(
                    currency: fromCurrency,
                    limit: sendingLimit
                )
            }
        }
    }

    private func activeAmount(for source: ConversionSource) -> Decimal {
        switch source {
        case .sendingAmount:
            return amount
        case .receivingAmount:
            return convertedAmount
        }
    }

    private func clearConversionState(source: ConversionSource) {
        isLoading = false
        errorState = nil
        clearCalculatedAmount(source: source)
    }

    private func clearStaleConversionData(source: ConversionSource) {
        clearCalculatedAmount(source: source)
        latestBackendRate = nil
        conversionRate = nil
    }

    private func clearCalculatedAmount(source: ConversionSource) {
        isApplyingConversionResult = true
        defer { isApplyingConversionResult = false }

        switch source {
        case .sendingAmount:
            convertedAmount = 0
        case .receivingAmount:
            amount = 0
        }
    }

    private func currencyPairDidChange() {
        guard !isApplyingConversionResult else {
            return
        }

        latestBackendRate = nil
        conversionRate = nil
        clearCalculatedAmount(source: .sendingAmount)

        if amount == 0 {
            fetchReferenceRate()
        } else {
            fetchConversionForCurrencyPairChange()
        }
    }

    private func fetchConversionForCurrencyPairChange() {
        invalidatePendingRequest()
        startCurrencyPairConversion()
    }

    private func startCurrencyPairConversion() {
        guard updateSendingLimitValidation() else {
            clearStaleConversionData(source: .sendingAmount)
            fetchReferenceRate(preservesSendingLimitError: true)
            return
        }

        isLoading = true
        clearNonNetworkError()

        start(
            makeConversionRequest(
                source: .sendingAmount,
                preservesSendingLimitError: false
            )
        )
    }

    @discardableResult
    private func updateSendingLimitValidation() -> Bool {
        guard let sendingLimit = validator.limit(for: fromCurrency) else {
            errorState = .conversionFailed
            return false
        }

        guard amount > sendingLimit else {
            if isSendingLimitExceeded {
                errorState = nil
            }

            return true
        }

        errorState = .sendingLimitExceeded(
            currency: fromCurrency,
            limit: sendingLimit
        )
        return false
    }

    private func fetchReferenceRate(preservesSendingLimitError: Bool = false) {
        invalidatePendingRequest()
        isLoading = true

        if !preservesSendingLimitError {
            clearNonNetworkError()
        }

        start(
            ConversionRequest(
                id: UUID(),
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                amount: 1,
                purpose: .referenceRate,
                preservesSendingLimitError: preservesSendingLimitError
            )
        )
    }

    private func start(_ request: ConversionRequest) {
        latestRequestID = request.id
        conversionTask = Task { [weak self] in
            await self?.fetchConversion(request)
        }
    }

    private func invalidatePendingRequest() {
        conversionTask?.cancel()
        latestRequestID = nil
    }

    private func clearNonNetworkError() {
        guard errorState != .networkError else {
            return
        }

        errorState = nil
    }

    private func storeLatestRate(_ rate: FXRate) {
        latestBackendRate = rate
        conversionRate = rate.displayedRate(
            from: fromCurrency,
            to: toCurrency
        )
    }

    private func isCurrentRequest(_ request: ConversionRequest) -> Bool {
        !Task.isCancelled && latestRequestID == request.id
    }

    private func makeConversionRequest(
        source: ConversionSource,
        preservesSendingLimitError: Bool
    ) -> ConversionRequest {
        let requestCurrencies: (from: Currency, to: Currency)

        switch source {
        case .sendingAmount:
            requestCurrencies = (fromCurrency, toCurrency)
        case .receivingAmount:
            requestCurrencies = (toCurrency, fromCurrency)
        }

        return ConversionRequest(
            id: UUID(),
            fromCurrency: requestCurrencies.from,
            toCurrency: requestCurrencies.to,
            amount: activeAmount(for: source),
            purpose: .conversion(source),
            preservesSendingLimitError: preservesSendingLimitError
        )
    }
}

private extension Decimal {
    func roundedForCurrencyDisplay() -> Decimal {
        var value = self
        var roundedValue = Decimal()
        NSDecimalRound(&roundedValue, &value, 2, .plain)
        return roundedValue
    }
}
