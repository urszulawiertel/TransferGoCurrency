import SwiftUI

struct ErrorView: View {
    let errorState: CurrencyConverterErrorState

    var body: some View {
        Text(errorState.message)
            .font(.footnote)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}
