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

    func testEditingFormatterParsesUngroupedInteger() {
        let formatter = CurrencyAmountEditingFormatter(locale: Locale(identifier: "pl_PL"))

        XCTAssertEqual(formatter.decimal(from: "3000"), 3000)
    }

    func testEditingFormatterDoesNotAddGroupingSeparator() {
        let formatter = CurrencyAmountEditingFormatter(locale: Locale(identifier: "pl_PL"))

        XCTAssertEqual(formatter.string(from: 3000), "3000")
    }

    func testEditingFormatterAcceptsPolishDecimalSeparator() {
        let formatter = CurrencyAmountEditingFormatter(locale: Locale(identifier: "pl_PL"))

        XCTAssertEqual(formatter.decimal(from: "1000"), Decimal(string: "1000"))
        XCTAssertEqual(formatter.decimal(from: "1000,5"), Decimal(string: "1000.5"))
        XCTAssertEqual(formatter.decimal(from: "1000,50"), Decimal(string: "1000.50"))
        XCTAssertEqual(formatter.decimal(from: "3000,50"), Decimal(string: "3000.50"))
    }

    func testEditingFormatterAcceptsEnglishDecimalSeparator() {
        let formatter = CurrencyAmountEditingFormatter(locale: Locale(identifier: "en_US"))

        XCTAssertEqual(formatter.decimal(from: "1000"), Decimal(string: "1000"))
        XCTAssertEqual(formatter.decimal(from: "1000.5"), Decimal(string: "1000.5"))
        XCTAssertEqual(formatter.decimal(from: "1000.50"), Decimal(string: "1000.50"))
        XCTAssertEqual(formatter.decimal(from: "3000.50"), Decimal(string: "3000.50"))
    }

    func testExternalValueSynchronizesEditingText() {
        var state = CurrencyAmountEditingState(value: 300, locale: Locale(identifier: "pl_PL"))

        state.synchronize(with: 3000)

        XCTAssertEqual(state.text, "3000")
    }

    func testEditingSameValueDoesNotProduceRepeatedBindingUpdate() {
        var state = CurrencyAmountEditingState(value: 300, locale: Locale(identifier: "pl_PL"))

        XCTAssertEqual(state.userEdited("3000", currentValue: 300), .changed(3000))
        XCTAssertEqual(state.userEdited("3000", currentValue: 3000), .unchanged)
    }

    func testPolishFractionalEditReturnsChangedDecimal() {
        var state = CurrencyAmountEditingState(value: 1000, locale: Locale(identifier: "pl_PL"))

        XCTAssertEqual(
            state.userEdited("1000,5", currentValue: 1000),
            .changed(Decimal(string: "1000.5")!)
        )
        XCTAssertEqual(state.text, "1000,5")
    }

    func testValidFractionalEditInvokesDecimalBindingUpdate() {
        var state = CurrencyAmountEditingState(value: 1000, locale: Locale(identifier: "pl_PL"))
        var updates: [Decimal] = []

        state.applyUserEdit("1000,5", currentValue: 1000) { updates.append($0) }

        XCTAssertEqual(updates, [Decimal(string: "1000.5")!])
        XCTAssertEqual(state.text, "1000,5")
    }

    func testLocaleInappropriateSeparatorDoesNotChangeTextOrValue() {
        var state = CurrencyAmountEditingState(value: 1000, locale: Locale(identifier: "pl_PL"))
        var updates: [Decimal] = []

        let result = state.applyUserEdit("1000.5", currentValue: 1000) { updates.append($0) }

        XCTAssertEqual(result, .invalid)
        XCTAssertTrue(updates.isEmpty)
        XCTAssertEqual(state.text, "1000")
    }

    func testFractionalTextRemainsExactlyAsTypedWhenValueIsNumericallyUnchanged() {
        var state = CurrencyAmountEditingState(
            value: Decimal(string: "1000.5")!,
            locale: Locale(identifier: "pl_PL")
        )

        let result = state.userEdited("1000,50", currentValue: Decimal(string: "1000.5")!)

        XCTAssertEqual(result, .unchanged)
        XCTAssertEqual(state.text, "1000,50")
    }
}
