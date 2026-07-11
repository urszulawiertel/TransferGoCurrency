import Foundation

public struct Currency: Equatable, Hashable, Identifiable, Sendable {
    public let code: String

    public var id: String {
        code
    }

    var flagAssetName: String {
        switch code {
        case "PLN": "pl_flag_large"
        case "EUR": "de_flag_large"
        case "GBP": "gb_flag_large"
        case "UAH": "ua_flag_large"
        default: ""
        }
    }

    public init(code: String) {
        self.code = code.uppercased()
    }
}
