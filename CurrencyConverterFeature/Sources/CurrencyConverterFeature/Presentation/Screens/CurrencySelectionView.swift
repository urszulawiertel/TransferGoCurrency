import SwiftUI

@MainActor
public struct CurrencySelectionView: View {
    @StateObject private var viewModel: CurrencySelectionViewModel
    private let onSelect: (SupportedCurrency) -> Void

    public init(onSelect: @escaping (SupportedCurrency) -> Void = { _ in }) {
        _viewModel = StateObject(wrappedValue: CurrencySelectionViewModel())
        self.onSelect = onSelect
    }

    init(
        viewModel: CurrencySelectionViewModel,
        onSelect: @escaping (SupportedCurrency) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CurrencySearchBar(
                text: $viewModel.searchText,
                placeholder: CurrencyConverterLocalization.string(.currencySelectionSearchPlaceholder)
            )
            .padding(.horizontal, 16)

            Text(CurrencyConverterLocalization.string(.currencySelectionAllCountries))
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredCurrencies) { supportedCurrency in
                        Button {
                            onSelect(supportedCurrency)
                        } label: {
                            CurrencyRowView(
                                supportedCurrency: supportedCurrency,
                                currencyName: viewModel.currencyName(for: supportedCurrency)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.currencySelectionBackground)
    }
}

private extension Color {
    static var currencySelectionBackground: Color {
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
    CurrencySelectionView()
}
