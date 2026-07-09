import Foundation

struct Currency: Equatable, Hashable, Identifiable, Sendable {
    let code: String

    var id: String {
        code
    }

    init(code: String) {
        self.code = code.uppercased()
    }
}
