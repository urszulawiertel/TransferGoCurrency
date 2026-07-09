import XCTest
@testable import CurrencyConverterFeature

final class CurrencyLimitValidatorTests: XCTestCase {
    func testCurrencyCodeIsUppercased() {
        XCTAssertEqual(Currency(code: "pln").code, "PLN")
        XCTAssertEqual(Currency(code: "eur").id, "EUR")
    }

    func testSupportedCurrencies() {
        XCTAssertEqual(SupportedCurrency.all.map(\.currency.code), ["PLN", "EUR", "GBP", "UAH"])
        XCTAssertEqual(SupportedCurrency.poland.country, "Poland")
        XCTAssertEqual(SupportedCurrency.germany.country, "Germany")
        XCTAssertEqual(SupportedCurrency.greatBritain.country, "Great Britain")
        XCTAssertEqual(SupportedCurrency.ukraine.country, "Ukraine")
    }

    func testLimitsForSupportedCurrencies() {
        let validator = CurrencyLimitValidator()

        XCTAssertEqual(validator.limit(for: Currency(code: "PLN")), 20_000)
        XCTAssertEqual(validator.limit(for: Currency(code: "EUR")), 5_000)
        XCTAssertEqual(validator.limit(for: Currency(code: "GBP")), 1_000)
        XCTAssertEqual(validator.limit(for: Currency(code: "UAH")), 50_000)
    }

    func testCanSendAmountAtOrBelowLimit() {
        let validator = CurrencyLimitValidator()

        XCTAssertTrue(validator.canSend(amount: 20_000, currency: Currency(code: "PLN")))
        XCTAssertTrue(validator.canSend(amount: 4_999.99, currency: Currency(code: "EUR")))
        XCTAssertTrue(validator.canSend(amount: 1_000, currency: Currency(code: "GBP")))
        XCTAssertTrue(validator.canSend(amount: 50_000, currency: Currency(code: "UAH")))
    }

    func testCannotSendAmountAboveLimit() {
        let validator = CurrencyLimitValidator()

        XCTAssertFalse(validator.canSend(amount: 20_000.01, currency: Currency(code: "PLN")))
        XCTAssertFalse(validator.canSend(amount: 5_000.01, currency: Currency(code: "EUR")))
        XCTAssertFalse(validator.canSend(amount: 1_000.01, currency: Currency(code: "GBP")))
        XCTAssertFalse(validator.canSend(amount: 50_000.01, currency: Currency(code: "UAH")))
    }

    func testCannotSendZeroNegativeOrUnsupportedCurrency() {
        let validator = CurrencyLimitValidator()

        XCTAssertFalse(validator.canSend(amount: 0, currency: Currency(code: "PLN")))
        XCTAssertFalse(validator.canSend(amount: -1, currency: Currency(code: "PLN")))
        XCTAssertFalse(validator.canSend(amount: 1, currency: Currency(code: "USD")))
    }
}
