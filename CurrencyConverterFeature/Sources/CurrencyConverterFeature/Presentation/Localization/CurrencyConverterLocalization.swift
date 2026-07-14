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
        case networkErrorTitle = "network_error_title"
        case networkErrorMessage = "network_error_message"
        case networkErrorDismissAccessibility = "network_error_dismiss_accessibility"
        case currencySelectionSearchPlaceholder = "currency_selection.search.placeholder"
        case currencySelectionAllCountries = "currency_selection.all_countries"
        case currencySelectionSendingTo = "currency_selection.sending_to"
        case currencySelectionClose = "currency_selection.close"
        case polishZloty = "currency.name.pln"
        case euro = "currency.name.eur"
        case britishPound = "currency.name.gbp"
        case ukrainianHryvnia = "currency.name.uah"
    }

    static func string(_ key: Key) -> String {
        NSLocalizedString(key.rawValue, bundle: .module, comment: "")
    }

    static func string(_ key: Key, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
