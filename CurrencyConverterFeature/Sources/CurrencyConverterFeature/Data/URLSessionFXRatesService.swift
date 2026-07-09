import Foundation

final class URLSessionFXRatesService: FXRatesServicing {
    private let endpointURL: URL?
    private let urlSession: URLSession

    init(
        endpointURL: URL? = URL(string: "https://my.transfergo.com/api/fx-rates"),
        urlSession: URLSession = .shared
    ) {
        self.endpointURL = endpointURL
        self.urlSession = urlSession
    }

    func rate(from sourceCurrency: Currency, to targetCurrency: Currency, amount: Decimal) async throws -> FXRate {
        let url = try makeURL(from: sourceCurrency, to: targetCurrency, amount: amount)
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FXRatesServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FXRatesServiceError.unacceptableStatusCode(httpResponse.statusCode)
        }

        return try decodeRate(from: data)
    }

    private func makeURL(from sourceCurrency: Currency, to targetCurrency: Currency, amount: Decimal) throws -> URL {
        guard let endpointURL else {
            throw FXRatesServiceError.invalidURL
        }

        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)

        components?.queryItems = [
            URLQueryItem(name: "from", value: sourceCurrency.code),
            URLQueryItem(name: "to", value: targetCurrency.code),
            URLQueryItem(name: "amount", value: NSDecimalNumber(decimal: amount).stringValue)
        ]

        guard let url = components?.url else {
            throw FXRatesServiceError.invalidURL
        }

        return url
    }

    private func decodeRate(from data: Data) throws -> FXRate {
        let object = try JSONSerialization.jsonObject(with: data)

        guard let response = object as? [String: Any] else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Expected FX rates response object.")
            )
        }

        return FXRate(
            fromCurrency: Currency(code: try stringValue(forKey: "from", in: response)),
            toCurrency: Currency(code: try stringValue(forKey: "to", in: response)),
            rate: try decimalValue(forKey: "rate", in: response),
            fromAmount: try decimalValue(forKey: "fromAmount", in: response),
            toAmount: try decimalValue(forKey: "toAmount", in: response)
        )
    }

    private func stringValue(forKey key: String, in response: [String: Any]) throws -> String {
        guard let value = response[key] as? String else {
            throw DecodingError.keyNotFound(
                AnyCodingKey(stringValue: key),
                DecodingError.Context(codingPath: [], debugDescription: "Missing string value for \(key).")
            )
        }

        return value
    }

    private func decimalValue(forKey key: String, in response: [String: Any]) throws -> Decimal {
        if let value = response[key] as? String,
           let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) {
            return decimal
        }

        if let value = response[key] as? NSNumber,
           let decimal = Decimal(string: value.description(withLocale: Locale(identifier: "en_US_POSIX"))) {
            return decimal
        }

        throw DecodingError.keyNotFound(
            AnyCodingKey(stringValue: key),
            DecodingError.Context(codingPath: [], debugDescription: "Missing decimal value for \(key).")
        )
    }
}

enum FXRatesServiceError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unacceptableStatusCode(Int)
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
