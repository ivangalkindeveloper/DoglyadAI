import DoglyadUI
import SwiftUI
import UIKit

struct ExpandableMarkdownView: DView {
    @EnvironmentObject var theme: DTheme

    let text: String
    let backgroundColor: Color
    let collapsedLineLimit: Int
    let onTapContent: (() -> Void)?

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int = 3,
        onTapContent: (() -> Void)? = nil
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
        self.onTapContent = onTapContent
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
                markdown

                Button(.buttonCollapse) {
                    withAnimation(theme.animation) {
                        isExpanded.toggle()
                    }
                }
                .font(typography.linkSmall)
                .foregroundColor(color.primaryDefault)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                ZStack(
                    alignment: .bottomTrailing
                ) {
                    markdown
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, maxHeight: collapsedMarkdownHeight, alignment: .topLeading)
                        .clipped()

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
                            .allowsHitTesting(false)

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

    @ViewBuilder
    private var markdown: some View {
        if let onTapContent {
            Button(
                action: onTapContent
            ) {
                markdownContent
            }
            .buttonStyle(.plain)
        } else {
            markdownContent
        }
    }

    private var markdownContent: some View {
        DMarkdown(
            content: text
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
