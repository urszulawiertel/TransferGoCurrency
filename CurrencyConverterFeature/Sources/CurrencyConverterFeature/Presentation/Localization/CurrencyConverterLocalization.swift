import Foundation

enum CurrencyConverterLocalization {
    enum Key: String {
        case sendingFrom = "currency_converter.sending_from"
        case receiverGets = "currency_converter.receiver_gets"
        case amountPlaceholder = "currency_converter.amount.placeholder"
        case sendingFromCurrencyAccessibility = "currency_converter.sending_from.currency.accessibility"
        case receiverGetsCurrencyAccessibility = "currency_converter.receiver_gets.currency.accessibility"
        case conversionRate = "currency_converter.conversion_rate"
        case swapCurrenciesAccessibility = "currency_converter.swap_currencies.accessibility"
        case sendingLimitExceeded = "currency_converter.error.sending_limit_exceeded"
        case conversionFailed = "currency_converter.error.conversion_failed"
    }

    static func string(_ key: Key) -> String {
        NSLocalizedString(key.rawValue, bundle: .module, comment: "")
    }

    static func string(_ key: Key, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
