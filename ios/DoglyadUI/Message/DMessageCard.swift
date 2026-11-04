import SwiftUI

public struct DMessageCard: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let message: DMessage
    private let alignment: TextAlignment

    public init(
        type: DMessageType,
        title: LocalizedStringResource,
        description: LocalizedStringResource? = nil,
        alignment: TextAlignment = .leading,
    ) {
        message = DMessage(
            type: type,
            title: title,
            description: description,
        )
        self.alignment = alignment
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    public var body: some View {
        VStack(
            alignment: horizontalAlignment,
            spacing: .zero,
        ) {
            Text(
                message.title,
            )
            .font(
                typography.linkSmall,
            )
            .foregroundStyle(
                theme.color.grayscaleBackground,
            )
            .multilineTextAlignment(
                alignment,
            )

            if let description = message.description {
                Text(
                    description,
                )
                .font(
                    typography.textXSmall,
                )
                .foregroundStyle(
                    theme.color.grayscaleBackground,
                )
                .multilineTextAlignment(
                    alignment,
                )
            }
        }
        .padding(
            .horizontal,
            size.s16,
        )
        .padding(
            .vertical,
            size.s12,
        )
        .frame(
            maxWidth: .infinity,
            alignment: Alignment(
                horizontal: horizontalAlignment,
                vertical: .center,
            ),
        )
        .background(
            RoundedRectangle(
                cornerRadius: theme.size.adaptiveCardCornerRadius,
            )
            .fill(
                backgroundColor,
            ),
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
        type: .success,
        title: "Data deleted",
        description: "All application data has been successfully deleted",
    )
    .padding()
    .dThemeWrapper()
}
