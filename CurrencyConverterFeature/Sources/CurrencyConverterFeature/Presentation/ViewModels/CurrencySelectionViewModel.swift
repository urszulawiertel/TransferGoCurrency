import Combine
import Foundation

@MainActor
final class CurrencySelectionViewModel: ObservableObject {
    @Published var searchText = ""

    private let currencies: [SupportedCurrency]

    init(currencies: [SupportedCurrency] = SupportedCurrency.all) {
        self.currencies = currencies
    }

    var filteredCurrencies: [SupportedCurrency] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return currencies
        }

        return currencies.filter { supportedCurrency in
            [   supportedCurrency.country,
                currencyName(for: supportedCurrency),
                supportedCurrency.currency.code
            ].contains { value in
                value.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    func currencyName(for supportedCurrency: SupportedCurrency) -> String {
        switch supportedCurrency.currency.code {
        case "PLN": CurrencyConverterLocalization.string(.polishZloty)
        case "EUR": CurrencyConverterLocalization.string(.euro)
        case "GBP": CurrencyConverterLocalization.string(.britishPound)
        case "UAH": CurrencyConverterLocalization.string(.ukrainianHryvnia)
        default: supportedCurrency.currency.code
        }
    }

}
