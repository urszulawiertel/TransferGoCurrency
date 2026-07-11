import SwiftUI

@MainActor
public struct CurrencySelectionView: View {
    @StateObject private var viewModel: CurrencySelectionViewModel
    private let title: String
    private let onSelect: (SupportedCurrency) -> Void

    public init(
        title: String,
        onSelect: @escaping (SupportedCurrency) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: CurrencySelectionViewModel())
        self.title = title
        self.onSelect = onSelect
    }

    init(
        viewModel: CurrencySelectionViewModel,
        title: String,
        onSelect: @escaping (SupportedCurrency) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.title = title
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Text(title)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

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
                    ForEach(Array(viewModel.filteredCurrencies.enumerated()), id: \.element.id) { index, supportedCurrency in
                        VStack(spacing: 0) {
                            Button {
                                onSelect(supportedCurrency)
                            } label: {
                                CurrencyRowView(
                                    supportedCurrency: supportedCurrency,
                                    currencyName: viewModel.currencyName(for: supportedCurrency)
                                )
                            }
                            .buttonStyle(.plain)

                            if index < viewModel.filteredCurrencies.count - 1 {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
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
    CurrencySelectionView(
        title: CurrencyConverterLocalization.string(.sendingFrom)
    )
}
