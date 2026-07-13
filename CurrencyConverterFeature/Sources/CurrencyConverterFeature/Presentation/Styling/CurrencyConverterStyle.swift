import SwiftUI

enum CurrencyConverterStyle {
    static let sendingLimitError = Color(
        red: 248.0 / 255.0,
        green: 50.0 / 255.0,
        blue: 106.0 / 255.0
    )

    static let errorForeground = Color(
        red: 229.0 / 255.0,
        green: 71.0 / 255.0,
        blue: 109.0 / 255.0
    )
    static let errorBackground = errorForeground.opacity(0.10)

    static let secondaryText = Color(
        red: 108.0 / 255.0,
        green: 114.0 / 255.0,
        blue: 122.0 / 255.0
    )
    static let networkErrorShadow = Color(
        red: 0,
        green: 26.0 / 255.0,
        blue: 63.0 / 255.0
    ).opacity(0.16)

    static let secondarySurface = Color(
        red: 237.0 / 255.0,
        green: 240.0 / 255.0,
        blue: 244.0 / 255.0
    )
    static let brandAccent = Color(
        red: 49.0 / 255.0,
        green: 127.0 / 255.0,
        blue: 245.0 / 255.0
    )

    static var screenBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.primary.opacity(0.04)
        #endif
    }
}
