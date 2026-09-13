import SwiftUI

struct DMessageCard: DView {
    let theme: DTheme
    let message: DMessage

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero
        ) {
            Text(
                message.title
            )
            .font(typography.linkSmall)
            .foregroundStyle(theme.color.grayscaleBackground)
            .multilineTextAlignment(.leading)

            if let description = message.description {
                Text(
                    description
                )
                .font(typography.textXSmall)
                .foregroundStyle(theme.color.grayscaleBackground)
                .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, size.s16)
        .padding(.vertical, size.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: theme.size.adaptiveCardCornerRadius
            )
            .fill(backgroundColor)
        )
    }
}

private extension DMessageCard {
    var backgroundColor: LinearGradient {
        switch message.type {
        case .success:
            color.gradientPrimaryWeak
        case .error:
            color.gradientAccent
        }
    }
}

#Preview {
    DMessageCard(
        theme: DTheme.light,
        message: DMessage(
            type: .success,
            title: "Data deleted",
            description: "All application data has been successfully deleted"
        )
    )
    .padding()
    .dThemeWrapper()
}
