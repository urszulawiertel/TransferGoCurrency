import SwiftUI

struct ConversionRateView: View {
    let fromCurrency: Currency
    let toCurrency: Currency
    let conversionRate: Decimal?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .scaleEffect(0.65)
            }

            if let conversionRate {
                Text(
                    CurrencyConverterLocalization.string(
                        .conversionRate,
                        fromCurrency.code,
                        conversionRate.currencyConverterFormatted(minimumFractionDigits: 2, maximumFractionDigits: 4),
                        toCurrency.code
                    )
                )
            } else {
                Text(" ")
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 18, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black)
        )
    }
}
