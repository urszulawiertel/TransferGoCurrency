import SwiftUI

struct CurrencyRowView: View {
    let supportedCurrency: SupportedCurrency
    let currencyName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(supportedCurrency.currency.flagAssetName, bundle: .module)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(supportedCurrency.country)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(currencyName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(supportedCurrency.currency.code)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 72)
        .contentShape(Rectangle())
    }
}
