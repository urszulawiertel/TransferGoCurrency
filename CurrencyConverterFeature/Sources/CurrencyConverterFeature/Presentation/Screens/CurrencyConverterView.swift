import SwiftUI

@MainActor
public struct CurrencyConverterView: View {
    @StateObject private var viewModel: CurrencyConverterViewModel
    @State private var selectionContext: CurrencySelectionContext?

    public init() {
        _viewModel = StateObject(wrappedValue: CurrencyConverterViewModel())
    }

    init(viewModel: CurrencyConverterViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CurrencyConverterStyle.sectionBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    CurrencyInputSection(
                        title: CurrencyConverterLocalization.string(.sendingFrom),
                        currencyAccessibilityLabel: CurrencyConverterLocalization.string(.sendingFromCurrencyAccessibility),
                        selectedCurrency: viewModel.fromCurrency,
                        amount: $viewModel.amount,
                        style: .sending,
                        showsSendingLimitError: viewModel.isSendingLimitExceeded,
                        onSelectCurrency: { selectionContext = .from }
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white)
                    )
                    .shadow(
                        color: .black.opacity(0.10),
                        radius: 8,
                        x: 0,
                        y: 2
                    )

                    CurrencyInputSection(
                        title: CurrencyConverterLocalization.string(.receiverGets),
                        currencyAccessibilityLabel: CurrencyConverterLocalization.string(.receiverGetsCurrencyAccessibility),
                        selectedCurrency: viewModel.toCurrency,
                        amount: $viewModel.convertedAmount,
                        style: .receiving,
                        onSelectCurrency: { selectionContext = .to }
                    )
                }

                SwapButton {
                    viewModel.swapCurrencies()
                }
                // The 44-point hit target extends 10 points beyond the visible circle.
                .offset(x: 34, y: 70)

                ConversionRateView(
                    fromCurrency: viewModel.fromCurrency,
                    toCurrency: viewModel.toCurrency,
                    conversionRate: viewModel.conversionRate,
                    isLoading: viewModel.isLoading
                )
                .offset(x: 110, y: 83)
            }
            .frame(maxWidth: 320, minHeight: 184, maxHeight: 184)

            if let errorState = viewModel.errorState,
               errorState != .networkError {
                ErrorView(errorState: errorState)
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 88)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.currencyConverterScreenBackground)
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                if viewModel.isNetworkErrorVisible {
                    NetworkErrorBanner {
                        viewModel.dismissNetworkError()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                    )
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.2), value: viewModel.isNetworkErrorVisible)
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $selectionContext) { context in
            CurrencySelectionView(title: context.title) { supportedCurrency in
                select(supportedCurrency.currency, for: context)
            }
        }
    }

    private func select(_ currency: Currency, for context: CurrencySelectionContext) {
        switch context {
        case .from:
            viewModel.fromCurrency = currency
        case .to:
            viewModel.toCurrency = currency
        }

        selectionContext = nil
    }
}

private enum CurrencySelectionContext: Identifiable {
    case from
    case to

    var id: Self { self }

    var title: String {
        switch self {
        case .from:
            CurrencyConverterLocalization.string(.sendingFrom)
        case .to:
            CurrencyConverterLocalization.string(.currencySelectionSendingTo)
        }
    }
}

private extension Color {
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
