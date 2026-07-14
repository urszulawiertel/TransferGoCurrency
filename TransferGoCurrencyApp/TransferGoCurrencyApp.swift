import CurrencyConverterFeature
import Foundation
import SwiftUI

@main
struct TransferGoCurrencyApp: App {
    var body: some Scene {
        WindowGroup {
            currencyConverterView
        }
    }

    @ViewBuilder
    private var currencyConverterView: some View {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-simulateNetworkError") {
            CurrencyConverterView(fxRatesService: SimulatedNetworkErrorFXRatesService())
        } else {
            CurrencyConverterView()
        }
#else
        CurrencyConverterView()
#endif
    }
}
