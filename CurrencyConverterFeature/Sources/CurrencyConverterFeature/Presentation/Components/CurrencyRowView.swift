import SwiftUI

struct CurrencyRowView: View {
    let supportedCurrency: SupportedCurrency
    let currencyName: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(CurrencyConverterStyle.secondarySurface)

                Image(supportedCurrency.currency.flagAssetName, bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(supportedCurrency.country)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 72)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        "\(currencyName) • \(supportedCurrency.currency.code)"
    }
}
