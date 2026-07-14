import XCTest
@testable import CurrencyConverterFeature

final class FXRateTests: XCTestCase {
    private let pln = Currency(code: "PLN")
    private let uah = Currency(code: "UAH")
    private let eur = Currency(code: "EUR")

    func testDisplayedRateForDirectPairReturnsOriginalRate() {
        let rate = makeRate(rate: 10)

        XCTAssertEqual(rate.displayedRate(from: pln, to: uah), 10)
    }

    func testDisplayedRateForReversedPairReturnsReciprocalRate() {
        let rate = makeRate(rate: 10)

        XCTAssertEqual(rate.displayedRate(from: uah, to: pln), Decimal(string: "0.1"))
    }

    func testDisplayedRateForReversedPairWithZeroRateReturnsNil() {
        let rate = makeRate(rate: 0)

        XCTAssertNil(rate.displayedRate(from: uah, to: pln))
    }

    func testDisplayedRateForUnrelatedPairReturnsNil() {
        let rate = makeRate(rate: 10)

        XCTAssertNil(rate.displayedRate(from: pln, to: eur))
    }

    private func makeRate(rate: Decimal) -> FXRate {
        FXRate(
            fromCurrency: pln,
            toCurrency: uah,
            rate: rate,
            fromAmount: 1,
            toAmount: rate
        )
    }
}
