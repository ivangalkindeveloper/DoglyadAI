import DoglyadUI
import SwiftUI

struct ReportDetailModelReportSectionView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let title: LocalizedStringResource
    let text: String
    let collapsedLineLimit: Int
    var isDisabled: Bool = false

    init(
        title: LocalizedStringResource,
        text: String,
        collapsedLineLimit: Int,
        isDisabled: Bool = false,
    ) {
        self.title = title
        self.text = text
        self.collapsedLineLimit = collapsedLineLimit
        self.isDisabled = isDisabled
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DText(
                title,
            )
            .dStyle(
                font: typography.linkSmall,
                color: color.grayscalePlacehold,
            )

            ReportDetailExpandableMarkdownView(
                text: text,
                backgroundColor: color.grayscaleBackground,
                collapsedLineLimit: collapsedLineLimit,
                isDisabled: isDisabled,
            )
        }
    }
}
