import Foundation

public struct Currency: Equatable, Identifiable, Sendable {
    public let code: String

    public var id: String {
        code
    }

    public init(code: String) {
        self.code = code
    }
}

