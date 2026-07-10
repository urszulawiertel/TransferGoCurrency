import SwiftUI

struct ConversionRateView: View {
    let fromCurrency: Currency
    let toCurrency: Currency
    let conversionRate: Decimal?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if let conversionRate {
                Text("1 \(fromCurrency.code) = \(conversionRate.currencyConverterFormatted(minimumFractionDigits: 2, maximumFractionDigits: 4)) \(toCurrency.code)")
            } else {
                Text(" ")
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(minHeight: 44, alignment: .center)
    }
}
