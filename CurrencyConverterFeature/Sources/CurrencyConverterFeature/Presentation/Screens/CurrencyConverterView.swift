import SwiftUI

@MainActor
public struct CurrencyConverterView: View {
    @StateObject private var viewModel: CurrencyConverterViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: CurrencyConverterViewModel())
    }

    init(viewModel: CurrencyConverterViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 16) {
                CurrencyInputSection(
                    title: CurrencyConverterLocalization.string(.sendingFrom),
                    currencyAccessibilityLabel: CurrencyConverterLocalization.string(.sendingFromCurrencyAccessibility),
                    selectedCurrency: $viewModel.fromCurrency,
                    amount: $viewModel.amount
                )

                HStack(spacing: 12) {
                    ConversionRateView(
                        fromCurrency: viewModel.fromCurrency,
                        toCurrency: viewModel.toCurrency,
                        conversionRate: viewModel.conversionRate,
                        isLoading: viewModel.isLoading
                    )

                    Spacer(minLength: 12)

                    SwapButton {
                        viewModel.swapCurrencies()
                    }
                }

                CurrencyInputSection(
                    title: CurrencyConverterLocalization.string(.receiverGets),
                    currencyAccessibilityLabel: CurrencyConverterLocalization.string(.receiverGetsCurrencyAccessibility),
                    selectedCurrency: $viewModel.toCurrency,
                    amount: $viewModel.convertedAmount
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.currencyConverterCardBackground)
            )

            if let errorState = viewModel.errorState {
                ErrorView(errorState: errorState)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.currencyConverterScreenBackground)
        .task {
            await viewModel.load()
        }
    }
}

private extension Color {
    static var currencyConverterCardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.secondary.opacity(0.12)
        #endif
    }

    static var currencyConverterScreenBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.primary.opacity(0.04)
        #endif
    }
}

#Preview {
    CurrencyConverterView()
}
