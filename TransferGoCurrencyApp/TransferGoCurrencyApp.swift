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

#if DEBUG
private struct SimulatedNetworkErrorFXRatesService: FXRatesServicing {
    func rate(
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        amount: Decimal
    ) async throws -> FXRate {
        throw URLError(.notConnectedToInternet)
    }
}
#endif
