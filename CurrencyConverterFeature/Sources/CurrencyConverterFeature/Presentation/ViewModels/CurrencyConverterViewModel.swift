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
        isLoading = false
        isApplyingConversionResult = false
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

        guard activeAmount.isWholeAmount else {
            isLoading = false
            errorState = .fractionalAmountNotSupported
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

            switch request.purpose {
            case let .conversion(source):
                apply(
                    rate: rate,
                    source: source,
                    preservesSendingLimitError: request.preservesSendingLimitError
                )
            case .referenceRate:
                latestBackendRate = rate
                conversionRate = rate.displayedRate(
                    from: fromCurrency,
                    to: toCurrency
                )
                errorState = nil
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
        source: ConversionSource,
        preservesSendingLimitError: Bool
    ) {
        isApplyingConversionResult = true
        latestBackendRate = rate
        conversionRate = rate.displayedRate(
            from: fromCurrency,
            to: toCurrency
        )

        if !preservesSendingLimitError {
            errorState = nil
        }

        switch source {
        case .sendingAmount:
            convertedAmount = rate.toAmount
        case .receivingAmount:
            amount = rate.toAmount

            guard let sendingLimit = validator.limit(for: fromCurrency) else {
                errorState = .conversionFailed
                isApplyingConversionResult = false
                return
            }

            if rate.toAmount > sendingLimit {
                errorState = .sendingLimitExceeded(
                    currency: fromCurrency,
                    limit: sendingLimit
                )
            }
        }

        isApplyingConversionResult = false
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

        switch source {
        case .sendingAmount:
            convertedAmount = 0
        case .receivingAmount:
            amount = 0
        }

        isApplyingConversionResult = false
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
        _ = updateSendingLimitValidation()
        let preservesSendingLimitError = isSendingLimitExceeded

        guard amount.isWholeAmount else {
            isLoading = false
            if !preservesSendingLimitError {
                errorState = .fractionalAmountNotSupported
            }
            return
        }

        isLoading = true

        if !preservesSendingLimitError {
            clearNonNetworkError()
        }

        start(
            makeConversionRequest(
                source: .sendingAmount,
                preservesSendingLimitError: preservesSendingLimitError
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

    private func fetchReferenceRate() {
        guard !isApplyingConversionResult else {
            return
        }

        invalidatePendingRequest()
        isLoading = true
        clearNonNetworkError()

        start(
            ConversionRequest(
                id: UUID(),
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                amount: 1,
                purpose: .referenceRate,
                preservesSendingLimitError: false
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

    private func isCurrentRequest(_ request: ConversionRequest) -> Bool {
        !Task.isCancelled && latestRequestID == request.id
    }

    private func makeConversionRequest(
        source: ConversionSource,
        preservesSendingLimitError: Bool
    ) -> ConversionRequest {
        switch source {
        case .sendingAmount:
            return ConversionRequest(
                id: UUID(),
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                amount: amount,
                purpose: .conversion(source),
                preservesSendingLimitError: preservesSendingLimitError
            )
        case .receivingAmount:
            return ConversionRequest(
                id: UUID(),
                fromCurrency: toCurrency,
                toCurrency: fromCurrency,
                amount: convertedAmount,
                purpose: .conversion(source),
                preservesSendingLimitError: preservesSendingLimitError
            )
        }
    }
}
