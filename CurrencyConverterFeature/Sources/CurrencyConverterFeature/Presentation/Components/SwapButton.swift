import SwiftUI

struct SwapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.accentColor))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CurrencyConverterLocalization.string(.swapCurrenciesAccessibility))
    }
}
