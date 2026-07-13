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

    private let fxRatesService: FXRatesServicing
    private let validator: CurrencyLimitValidator
    private var conversionTask: Task<Void, Never>?
    private var latestRequestID: UUID?
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

        hasLoaded = true
        fetchConversionIfNeeded(source: .sendingAmount)
        await conversionTask?.value
    }

    func swapCurrencies() {
        isApplyingConversionResult = true
        let previousFromCurrency = fromCurrency
        fromCurrency = toCurrency
        toCurrency = previousFromCurrency

        let previousAmount = amount
        amount = convertedAmount
        convertedAmount = previousAmount
        isApplyingConversionResult = false

        currencyPairDidChange()
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

        switch source {
        case .sendingAmount:
            guard let sendingLimit = validator.limit(for: fromCurrency) else {
                isLoading = false
                errorState = .conversionFailed
                clearStaleConversionData(source: source)
                return
            }

            guard amount <= sendingLimit else {
                isLoading = false
                errorState = .sendingLimitExceeded(
                    currency: fromCurrency,
                    limit: sendingLimit
                )
                return
            }
        case .receivingAmount:
            break
        }

        isLoading = true
        errorState = nil

        start(makeConversionRequest(source: source))
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
                apply(rate: rate, source: source)
            case .referenceRate:
                conversionRate = rate.rate
            }
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentRequest(request) else {
                return
            }

            errorState = .conversionFailed
            isLoading = false
        }
    }

    private func apply(rate: FXRate, source: ConversionSource) {
        isApplyingConversionResult = true

        switch source {
        case .sendingAmount:
            convertedAmount = rate.toAmount
            conversionRate = rate.rate
        case .receivingAmount:
            amount = rate.toAmount
            conversionRate = displayedRate(fromReversedRate: rate.rate)

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
        conversionRate = nil

        if amount == 0 {
            fetchReferenceRate()
        } else {
            fetchConversionIfNeeded(source: .sendingAmount)
        }
    }

    private func fetchReferenceRate() {
        guard !isApplyingConversionResult else {
            return
        }

        invalidatePendingRequest()
        isLoading = true
        errorState = nil

        start(
            ConversionRequest(
                id: UUID(),
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                amount: 1,
                purpose: .referenceRate
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

    private func displayedRate(fromReversedRate rate: Decimal) -> Decimal? {
        guard rate != 0 else {
            return nil
        }

        return 1 / rate
    }

    private func isCurrentRequest(_ request: ConversionRequest) -> Bool {
        !Task.isCancelled && latestRequestID == request.id
    }

    private func makeConversionRequest(source: ConversionSource) -> ConversionRequest {
        switch source {
        case .sendingAmount:
            return ConversionRequest(
                id: UUID(),
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                amount: amount,
                purpose: .conversion(source)
            )
        case .receivingAmount:
            return ConversionRequest(
                id: UUID(),
                fromCurrency: toCurrency,
                toCurrency: fromCurrency,
                amount: convertedAmount,
                purpose: .conversion(source)
            )
        }
    }
}

enum CurrencyConverterErrorState: Equatable {
    case sendingLimitExceeded(currency: Currency, limit: Decimal)
    case conversionFailed

    var message: String {
        switch self {
        case let .sendingLimitExceeded(currency, limit):
            return CurrencyConverterLocalization.string(
                .sendingLimitExceeded,
                limit.currencyConverterFormatted(),
                currency.code
            )
        case .conversionFailed:
            return CurrencyConverterLocalization.string(.conversionFailed)
        }
    }
}

private enum ConversionSource {
    case sendingAmount
    case receivingAmount
}

private struct ConversionRequest {
    let id: UUID
    let fromCurrency: Currency
    let toCurrency: Currency
    let amount: Decimal
    let purpose: ConversionRequestPurpose
}

private enum ConversionRequestPurpose {
    case conversion(ConversionSource)
    case referenceRate
}
