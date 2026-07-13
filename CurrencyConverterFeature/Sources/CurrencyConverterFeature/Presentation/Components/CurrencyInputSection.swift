import SwiftUI

@MainActor
struct CurrencyInputSection: View {
    enum Style {
        case sending
        case receiving

        var amountColor: Color {
            switch self {
            case .sending:
                CurrencyConverterStyle.brandAccent
            case .receiving:
                .black
            }
        }
    }

    let title: String
    let currencyAccessibilityLabel: String
    let selectedCurrency: Currency
    @Binding var amount: Decimal
    let style: Style
    let showsSendingLimitError: Bool
    let onSelectCurrency: () -> Void
    @State private var editingState: CurrencyAmountEditingState

    init(
        title: String,
        currencyAccessibilityLabel: String,
        selectedCurrency: Currency,
        amount: Binding<Decimal>,
        style: Style,
        showsSendingLimitError: Bool = false,
        onSelectCurrency: @escaping () -> Void
    ) {
        self.title = title
        self.currencyAccessibilityLabel = currencyAccessibilityLabel
        self.selectedCurrency = selectedCurrency
        _amount = amount
        self.style = style
        self.showsSendingLimitError = showsSendingLimitError
        self.onSelectCurrency = onSelectCurrency
        _editingState = State(initialValue: CurrencyAmountEditingState(value: amount.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CurrencyConverterStyle.secondaryText)

            HStack(spacing: 12) {
                currencySelector

                TextField(
                    CurrencyConverterLocalization.string(.amountPlaceholder),
                    text: Binding(
                        get: { editingState.text },
                        set: { newValue in
                            editingState.applyUserEdit(newValue, currentValue: amount) {
                                amount = $0
                            }
                        }
                    )
                )
                .currencyConverterDecimalKeyboard()
                .multilineTextAlignment(.trailing)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(amountColor)
                .textFieldStyle(.plain)
            }
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .leading)
        .overlay {
            if showsSendingLimitError {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CurrencyConverterStyle.sendingLimitError, lineWidth: 1)
            }
        }
        .onChange(of: amount) { _, newAmount in
            editingState.synchronize(with: newAmount)
        }
    }

    private var amountColor: Color {
        showsSendingLimitError ? CurrencyConverterStyle.sendingLimitError : style.amountColor
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
                    .font(.body.weight(.bold))

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CurrencyConverterStyle.secondaryText)
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
