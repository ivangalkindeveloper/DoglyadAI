import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListExpandableTextView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let text: String
    let backgroundColor: Color
    let collapsedLineLimit: Int
    let onTapContent: (() -> Void)?

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int = 3,
        onTapContent: (() -> Void)? = nil,
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
        self.onTapContent = onTapContent
    }

    var body: some View {
        ExpandableContentView(
            text: text,
            backgroundColor: backgroundColor,
            collapsedLineLimit: collapsedLineLimit,
            onTapContent: onTapContent,
        ) {
            DText(
                text,
            )
            .dStyle(
                font: typography.textMedium,
                color: color.grayscaleHeader,
                alignment: .leading,
            )
            .lineSpacing(
                16 * 0.15,
            )
        }
    }
}

#Preview {
    VStack(
        alignment: .leading,
        spacing: 24,
    ) {
        ReadyMadeTemplateListExpandableTextView(
            text: "Short plain text, including literal **asterisks**.",
            backgroundColor: .white,
        )

        ReadyMadeTemplateListExpandableTextView(
            text: """
            This is long plain text that should be truncated after several lines. \
            Markdown characters such as **bold** and [links](https://example.com) remain literal text. \
            The expanded view shows the entire text, and short content has no expand or collapse button.
            """,
            backgroundColor: .white,
        )
    }
    .padding()
    .dThemeWrapper()
    .localization(
        DependencyContainer.previewable.l10n,
    )
}
