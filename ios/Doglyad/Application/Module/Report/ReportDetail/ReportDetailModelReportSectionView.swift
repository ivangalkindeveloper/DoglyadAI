import DoglyadUI
import SwiftUI

struct ReportDetailModelReportSectionView: DView {
    @EnvironmentObject var theme: DTheme
    let title: LocalizedStringResource
    let text: String
    let collapsedLineLimit: Int

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

            ExpandableMarkdownView(
                text: text,
                backgroundColor: color.grayscaleBackground,
                collapsedLineLimit: collapsedLineLimit,
            )
        }
    }
}
