import SwiftUI

struct ErrorView: View {
    let errorState: CurrencyConverterErrorState

    var body: some View {
        HStack(spacing: 8) {
            Image("error_info", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(errorState.message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(CurrencyConverterStyle.errorForeground)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CurrencyConverterStyle.errorBackground)
        )
    }
}
