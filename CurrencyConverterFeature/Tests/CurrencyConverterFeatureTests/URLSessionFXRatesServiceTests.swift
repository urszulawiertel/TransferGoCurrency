import Foundation
import XCTest
@testable import CurrencyConverterFeature

final class URLSessionFXRatesServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testRateBuildsExpectedRequestAndDecodesResponse() async throws {
        let service = URLSessionFXRatesService(urlSession: makeURLSession())
        let responseData = Data(
            """
            {
              "from": "PLN",
              "to": "EUR",
              "rate": 0.23197,
              "fromAmount": 1000,
              "toAmount": 231.97
            }
            """.utf8
        )

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let queryItems = Self.queryItems(from: components)

            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "my.transfergo.com")
            XCTAssertEqual(url.path, "/api/fx-rates")
            XCTAssertEqual(queryItems["from"], "PLN")
            XCTAssertEqual(queryItems["to"], "EUR")
            XCTAssertEqual(queryItems["amount"], "1000")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )

            return (response, responseData)
        }

        let rate = try await service.rate(
            from: Currency(code: "pln"),
            to: Currency(code: "eur"),
            amount: 1_000
        )

        XCTAssertEqual(
            rate,
            FXRate(
                fromCurrency: Currency(code: "PLN"),
                toCurrency: Currency(code: "EUR"),
                rate: try Self.decimal("0.23197"),
                fromAmount: try Self.decimal("1000"),
                toAmount: try Self.decimal("231.97")
            )
        )
    }

    func testRateSerializesFractionalDecimalWithDotAndWithoutGrouping() async throws {
        let service = URLSessionFXRatesService(urlSession: makeURLSession())
        let responseData = Data(
            """
            {
              "from": "PLN",
              "to": "EUR",
              "rate": "1",
              "fromAmount": "1234567.89",
              "toAmount": "1234567.89"
            }
            """.utf8
        )

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let queryItems = Self.queryItems(from: components)

            XCTAssertEqual(queryItems["amount"], "1234567.89")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, responseData)
        }

        _ = try await service.rate(
            from: Currency(code: "PLN"),
            to: Currency(code: "EUR"),
            amount: try Self.decimal("1234567.89")
        )
    }

    func testRateThrowsStatusCodeErrorForUnsuccessfulResponse() async throws {
        let service = URLSessionFXRatesService(urlSession: makeURLSession())

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            )

            return (response, Data())
        }

        do {
            _ = try await service.rate(
                from: Currency(code: "PLN"),
                to: Currency(code: "EUR"),
                amount: 1_000
            )
            XCTFail("Expected service to throw for an unsuccessful status code.")
        } catch let error as FXRatesServiceError {
            XCTAssertEqual(error, .unacceptableStatusCode(500))
        }
    }

    func testRateThrowsInvalidResponseForNonHTTPResponse() async throws {
        let service = URLSessionFXRatesService(urlSession: makeURLSession())

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data())
        }

        do {
            _ = try await service.rate(
                from: Currency(code: "PLN"),
                to: Currency(code: "EUR"),
                amount: 1_000
            )
            XCTFail("Expected service to throw for a non-HTTP response.")
        } catch let error as FXRatesServiceError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRateThrowsInvalidURLWhenEndpointURLIsMissing() async {
        let service = URLSessionFXRatesService(endpointURL: nil, urlSession: makeURLSession())

        do {
            _ = try await service.rate(
                from: Currency(code: "PLN"),
                to: Currency(code: "EUR"),
                amount: 1_000
            )
            XCTFail("Expected service to throw for an invalid URL.")
        } catch let error as FXRatesServiceError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Expected FXRatesServiceError.invalidURL, got \(error).")
        }
    }

    private func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func queryItems(from components: URLComponents) -> [String: String] {
        (components.queryItems ?? []).reduce(into: [:]) { result, item in
            result[item.name] = item.value
        }
    }

    private static func decimal(_ value: String) throws -> Decimal {
        try XCTUnwrap(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (URLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
