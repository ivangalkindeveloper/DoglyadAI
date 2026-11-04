import DoglyadUI
import SwiftUI

struct ReportDetailExpandableTextView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let text: String
    let backgroundColor: Color
    let collapsedLineLimit: Int

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int = 3,
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
    }

    var body: some View {
        ExpandableContentView(
            text: text,
            backgroundColor: backgroundColor,
            collapsedLineLimit: collapsedLineLimit,
            collapsedFontSize: 14,
            collapsedLineSpacing: 0,
            onTapContent: nil,
        ) {
            DText(
                text,
            )
            .dStyle(
                font: typography.textSmall,
                alignment: .leading,
            )
        }
    }
}
