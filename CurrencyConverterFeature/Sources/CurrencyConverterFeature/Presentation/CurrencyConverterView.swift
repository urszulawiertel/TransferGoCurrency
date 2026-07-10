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
        Text("Currency Converter")
            .task {
                await viewModel.load()
            }
    }
}

#Preview {
    CurrencyConverterView()
}
