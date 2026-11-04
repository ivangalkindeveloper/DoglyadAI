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
