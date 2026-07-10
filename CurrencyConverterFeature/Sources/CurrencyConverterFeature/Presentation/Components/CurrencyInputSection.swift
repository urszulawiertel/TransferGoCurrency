import SwiftUI

@MainActor
struct CurrencyInputSection: View {
    let title: String
    @Binding var selectedCurrency: Currency
    @Binding var amount: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                currencySelector

                TextField(
                    "0",
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
        Menu {
            ForEach(SupportedCurrency.all) { supportedCurrency in
                Button {
                    selectedCurrency = supportedCurrency.currency
                } label: {
                    Text(supportedCurrency.currency.code)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedCurrency.code)
                    .font(.headline)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(minWidth: 76, minHeight: 36, alignment: .leading)
        }
        .accessibilityLabel("\(title) currency")
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
