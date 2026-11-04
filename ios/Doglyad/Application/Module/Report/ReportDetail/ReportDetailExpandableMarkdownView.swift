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
