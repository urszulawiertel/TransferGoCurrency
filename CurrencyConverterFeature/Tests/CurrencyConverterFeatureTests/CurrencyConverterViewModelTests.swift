import XCTest
@testable import CurrencyConverterFeature

final class CurrencyConverterViewModelTests: XCTestCase {
    func testInitialState() async throws {
        _ = await CurrencyConverterViewModel()
    }
}

