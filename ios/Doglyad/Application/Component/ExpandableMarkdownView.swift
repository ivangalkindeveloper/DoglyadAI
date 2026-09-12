import DoglyadUI
import SwiftUI
import UIKit

struct ExpandableMarkdownView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    let text: String
    let backgroundColor: Color
    let collapsedLineLimit: Int

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int = 3
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
    }

    @State private var isExpanded = false

    private var collapsedMarkdownHeight: CGFloat {
        let fontSize: CGFloat = 14
        let uiFont =
            UIFont(name: DFontFamily.MontserratRegular.rawValue, size: fontSize)
                ?? UIFont.systemFont(ofSize: fontSize)
        let line = ceil(uiFont.lineHeight * 1.12)
        return line * CGFloat(max(1, collapsedLineLimit))
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s4
        ) {
            if isExpanded {
                DMarkdown(
                    content: text
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(.buttonCollapse) {
                    withAnimation(theme.animation) {
                        isExpanded.toggle()
                    }
                }
                .font(typography.linkSmall)
                .foregroundColor(color.primaryDefault)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                DMarkdown(
                    content: text
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: collapsedMarkdownHeight, alignment: .topLeading)
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    HStack(
                        spacing: .zero
                    ) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        backgroundColor.opacity(0),
                                        backgroundColor,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 100, height: 16)

                        Button(.buttonNext) {
                            withAnimation(theme.animation) {
                                isExpanded.toggle()
                            }
                        }
                        .font(typography.linkSmall)
                        .foregroundColor(color.primaryDefault)
                        .background(backgroundColor)
                    }
                }
            }
        }
    }
}

#Preview {
    ExpandableMarkdownView(
        text: """
        This is **long** Markdown content that should be truncated after several lines. \
        The expanded view shows all markup. The collapsed view shows a gradient and a “More” button.
        """,
        backgroundColor: Color(.white)
    )
    .padding()
    .dThemeWrapper()
}
