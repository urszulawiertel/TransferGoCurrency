import SwiftUI

struct CurrencySearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("", text: $text)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(placeholder)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(placeholder)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }

            Text(placeholder)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .background(Color.white)
                .offset(x: 12, y: -7)
                .accessibilityHidden(true)
        }
    }
}
