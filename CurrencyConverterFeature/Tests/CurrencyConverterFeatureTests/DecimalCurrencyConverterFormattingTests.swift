import XCTest
@testable import CurrencyConverterFeature

final class DecimalCurrencyConverterFormattingTests: XCTestCase {
    func testFormattedUsesCurrentLocaleAndFractionDigitLimits() throws {
        let value = try XCTUnwrap(Decimal(string: "1234.567", locale: Locale(identifier: "en_US_POSIX")))
        let expectedFormatter = NumberFormatter()
        expectedFormatter.numberStyle = .decimal
        expectedFormatter.minimumFractionDigits = 2
        expectedFormatter.maximumFractionDigits = 2
        expectedFormatter.locale = .current

        XCTAssertEqual(
            value.currencyConverterFormatted(minimumFractionDigits: 2, maximumFractionDigits: 2),
            expectedFormatter.string(from: value as NSDecimalNumber)
        )
    }

    func testDecimalParsingAcceptsDotAndCommaSeparators() {
        XCTAssertEqual(Decimal.currencyConverterDecimal(from: "123.45"), 123.45)
        XCTAssertEqual(Decimal.currencyConverterDecimal(from: "123,45"), 123.45)
    }

    func testDecimalParsingTrimsWhitespaceAndTreatsEmptyInputAsZero() {
        XCTAssertEqual(Decimal.currencyConverterDecimal(from: "  123.45\n"), 123.45)
        XCTAssertEqual(Decimal.currencyConverterDecimal(from: "   "), 0)
    }

    func testDecimalParsingReturnsNilForInvalidInput() {
        XCTAssertNil(Decimal.currencyConverterDecimal(from: "not a number"))
    }
}
