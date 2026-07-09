import Foundation

struct SupportedCurrency: Equatable, Identifiable, Sendable {
    let currency: Currency
    let country: String
    let sendingLimit: Decimal

    var id: String {
        currency.id
    }

    init(currency: Currency, country: String, sendingLimit: Decimal) {
        self.currency = currency
        self.country = country
        self.sendingLimit = sendingLimit
    }
}

extension SupportedCurrency {
    static let poland = SupportedCurrency(
        currency: Currency(code: "PLN"),
        country: "Poland",
        sendingLimit: 20_000
    )

    static let germany = SupportedCurrency(
        currency: Currency(code: "EUR"),
        country: "Germany",
        sendingLimit: 5_000
    )

    static let greatBritain = SupportedCurrency(
        currency: Currency(code: "GBP"),
        country: "Great Britain",
        sendingLimit: 1_000
    )

    static let ukraine = SupportedCurrency(
        currency: Currency(code: "UAH"),
        country: "Ukraine",
        sendingLimit: 50_000
    )

    static let all: [SupportedCurrency] = [
        .poland,
        .germany,
        .greatBritain,
        .ukraine
    ]
}
