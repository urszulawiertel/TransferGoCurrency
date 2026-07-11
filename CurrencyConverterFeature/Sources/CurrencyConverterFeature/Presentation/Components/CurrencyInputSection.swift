import SwiftUI

@MainActor
struct CurrencyInputSection: View {
    let title: String
    let currencyAccessibilityLabel: String
    let selectedCurrency: Currency
    @Binding var amount: Decimal
    let onSelectCurrency: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                currencySelector

                TextField(
                    CurrencyConverterLocalization.string(.amountPlaceholder),
                    text: Binding(
                        get: { amount.currencyConverterFormatted() },
                        set: { newValue in
                            if let decimal = Decimal.currencyConverterDecimal(from: newValue) {
                                amount = decimal
                            }
                        }
                    )
                )
                .currencyConverterDecimalKeyboard()
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.plain)
            }
            .frame(minHeight: 44)
        }
    }

    private var currencySelector: some View {
        Button(action: onSelectCurrency) {
            HStack(spacing: 6) {
                Image(selectedCurrency.flagAssetName, bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                Text(selectedCurrency.code)
                    .font(.headline)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(currencyAccessibilityLabel)
    }
}

private extension View {
    @ViewBuilder
    func currencyConverterDecimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
