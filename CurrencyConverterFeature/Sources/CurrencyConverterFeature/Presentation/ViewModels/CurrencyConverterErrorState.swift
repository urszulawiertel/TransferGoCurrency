import Foundation

enum CurrencyConverterErrorState: Equatable {
    case sendingLimitExceeded(currency: Currency, limit: Decimal)
    case networkError
    case conversionFailed

    init(error: Error) {
        guard let urlError = error as? URLError else {
            self = .conversionFailed
            return
        }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            self = .networkError
        default:
            self = .conversionFailed
        }
    }

    var message: String {
        switch self {
        case let .sendingLimitExceeded(currency, limit):
            return CurrencyConverterLocalization.string(
                .sendingLimitExceeded,
                limit.currencyConverterFormatted(),
                currency.code
            )
        case .networkError:
            return CurrencyConverterLocalization.string(.networkErrorMessage)
        case .conversionFailed:
            return CurrencyConverterLocalization.string(.conversionFailed)
        }
    }
}
