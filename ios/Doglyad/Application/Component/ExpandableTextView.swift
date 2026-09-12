import DoglyadUI
import SwiftUI

struct ExpandableTextView: View {
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

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s4
        ) {
            if isExpanded {
                DText(text)
                    .dStyle(
                        font: typography.textSmall,
                        alignment: .leading
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
                DText(text)
                    .dStyle(
                        font: typography.textSmall,
                        alignment: .leading
                    )
                    .lineLimit(collapsedLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    ExpandableTextView(
        text: """
        This is long text that should be truncated after a specified number of lines. \
        The collapsed state should end with an ellipsis and a “More” button, \
        placed on the same line as the end of the truncated text. \
        Tapping the button expands the entire text.
        """,
        backgroundColor: Color(.white)
    )
    .padding()
    .dThemeWrapper()
}
