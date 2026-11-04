import SwiftUI

struct DStreamingMarkdownBlockView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    let block: DStreamingMarkdownBlock
    let date: Date
    let textColor: Color?

    var body: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 0,
        ) {
            if block.content.indent > 0 {
                DText(
                    block.content.marker ?? "",
                )
                .dStyle(
                    font: typography.textMedium,
                    color: textColor ?? color.grayscaleHeader,
                )
                .frame(
                    minWidth: 24,
                    alignment: .leading,
                )
            }

            switch block.content.kind {
            case .paragraph, .heading:
                Text(
                    DStreamingMarkdownTextRenderer.text(
                        for: block,
                        date: date,
                        color: color,
                        textColor: textColor,
                    ),
                )
                .lineSpacing(
                    block.content.kind == .paragraph ? 2.4 : 0,
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true,
                )
            case .fallback:
                DMarkdown(
                    content: block.content.markdown,
                    textColor: textColor,
                )
            }
        }
        .padding(
            .leading,
            Double(
                max(
                    0,
                    block.content.indent - 1,
                ),
            ) * 24,
        )
    }
}
