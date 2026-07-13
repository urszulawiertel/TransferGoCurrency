import SwiftUI

struct SwapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(CurrencyConverterStyle.primaryBlue))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CurrencyConverterLocalization.string(.swapCurrenciesAccessibility))
    }
}
