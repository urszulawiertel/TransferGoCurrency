import XCTest
@testable import CurrencyConverterFeature

@MainActor
final class CurrencySelectionViewModelTests: XCTestCase {
    func testEmptySearchReturnsAllSupportedCurrencies() {
        let viewModel = CurrencySelectionViewModel()

        XCTAssertEqual(viewModel.filteredCurrencies, SupportedCurrency.all)
    }

    func testFilteringByCountryNameIsCaseInsensitive() {
        let viewModel = CurrencySelectionViewModel()

        viewModel.searchText = "gReAt"

        XCTAssertEqual(viewModel.filteredCurrencies, [.greatBritain])
    }

    func testFilteringByCurrencyNameIsCaseInsensitive() {
        let viewModel = CurrencySelectionViewModel()

        viewModel.searchText = "HrYvNiA"

        XCTAssertEqual(viewModel.filteredCurrencies, [.ukraine])
    }

    func testFilteringByCurrencyCodeIsCaseInsensitive() {
        let viewModel = CurrencySelectionViewModel()

        viewModel.searchText = "eur"

        XCTAssertEqual(viewModel.filteredCurrencies, [.germany])
    }

    func testWhitespaceOnlySearchReturnsAllSupportedCurrencies() {
        let viewModel = CurrencySelectionViewModel()

        viewModel.searchText = "  \n "

        XCTAssertEqual(viewModel.filteredCurrencies, SupportedCurrency.all)
    }

    func testSearchWithNoMatchesReturnsEmptyResult() {
        let viewModel = CurrencySelectionViewModel()

        viewModel.searchText = "dollar"

        XCTAssertTrue(viewModel.filteredCurrencies.isEmpty)
    }
}
