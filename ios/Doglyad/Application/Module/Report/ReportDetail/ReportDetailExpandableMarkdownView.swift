import DoglyadUI
import SwiftUI

struct ReportDetailExpandableMarkdownView: DViewProtocol {
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
            DMarkdown(
                content: text,
            )
        }
    }
}

#Preview {
    VStack(
        alignment: .leading,
        spacing: 24,
    ) {
        ReportDetailExpandableMarkdownView(
            text: "Short **Markdown** content.",
            backgroundColor: .white,
        )

        ReportDetailExpandableMarkdownView(
            text: """
            This is **long** Markdown content that should be truncated after several lines. \
            The expanded view shows all markup. The collapsed view shows a gradient and an expand button. \
            Short content remains fully visible without an expand or collapse button.
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
