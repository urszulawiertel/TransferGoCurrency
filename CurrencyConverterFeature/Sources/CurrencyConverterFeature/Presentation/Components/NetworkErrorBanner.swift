import SwiftUI

struct NetworkErrorBanner: View {
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .body) private var titleFontSize = 16.0
    @ScaledMetric(relativeTo: .body) private var messageFontSize = 14.0
    @ScaledMetric(relativeTo: .body) private var dismissIconSize = 14.0
    @ScaledMetric(relativeTo: .body) private var titleLineHeight = 20.0

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image("network_error_icon", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(CurrencyConverterLocalization.string(.networkErrorTitle))
                    .font(.system(size: titleFontSize, weight: .bold))
                    .foregroundStyle(CurrencyConverterStyle.networkErrorTitle)

                Text(CurrencyConverterLocalization.string(.networkErrorMessage))
                    .font(.system(size: messageFontSize, weight: .regular))
                    .foregroundStyle(CurrencyConverterStyle.networkErrorMessage)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: dismissIconSize, weight: .semibold))
                    .foregroundStyle(CurrencyConverterStyle.networkErrorMessage)
                    .frame(width: titleLineHeight, height: titleLineHeight)
                    .padding(.top, 1)
                    .frame(minWidth: 44, minHeight: 44, alignment: .top)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(
                CurrencyConverterLocalization.string(.networkErrorDismissAccessibility)
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CurrencyConverterStyle.networkErrorBackground)
        )
        .shadow(
            color: CurrencyConverterStyle.networkErrorShadow,
            radius: 16,
            x: 0,
            y: 0
        )
    }
}

#Preview("Visible") {
    NetworkErrorBanner {}
        .padding(20)
        .background(Color.gray.opacity(0.1))
}

#Preview("Hidden") {
    VStack {
        if false {
            NetworkErrorBanner {}
        }
    }
    .frame(width: 320, height: 120)
    .padding(20)
    .background(Color.gray.opacity(0.1))
}
