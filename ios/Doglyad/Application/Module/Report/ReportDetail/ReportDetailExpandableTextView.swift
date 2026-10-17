import DoglyadUI
import SwiftUI

struct ReportDetailExpandableTextView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
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

    @State private var isExpanded = false

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s4,
        ) {
            if isExpanded {
                DText(
                    text,
                )
                .dStyle(
                    font: typography.textSmall,
                    alignment: .leading,
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                DButtonCard(
                    isPlain: true,
                    action: {
                        withAnimation(
                            theme.animation,
                        ) {
                            isExpanded.toggle()
                        }
                    },
                ) { DText(
                    l10n[
                        .buttonCollapse,
                    ],
                )
                .dStyle(
                    font: typography.linkSmall,
                    color: color.primaryDefault,
                )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .trailing,
                )
            } else {
                DText(
                    text,
                )
                .dStyle(
                    font: typography.textSmall,
                    alignment: .leading,
                )
                .lineLimit(
                    collapsedLineLimit,
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .overlay(
                    alignment: .bottomTrailing,
                ) {
                    HStack(
                        spacing: .zero,
                    ) {
                        DTextFade(
                            backgroundColor: backgroundColor,
                        )

                        DButtonCard(
                            isPlain: true,
                            action: {
                                withAnimation(
                                    theme.animation,
                                ) {
                                    isExpanded.toggle()
                                }
                            },
                        ) { DText(
                            l10n[
                                .buttonNext,
                            ],
                        )
                        .dStyle(
                            font: typography.linkSmall,
                            color: color.primaryDefault,
                        )
                        }
                        .background(
                            backgroundColor,
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    ReportDetailExpandableTextView(
        text: """
        This is long text that should be truncated after a specified number of lines. \
        The collapsed state should end with an ellipsis and a “More” button, \
        placed on the same line as the end of the truncated text. \
        Tapping the button expands the entire text.
        """,
        backgroundColor: Color(
            .white,
        ),
    )
    .padding()
    .dThemeWrapper()
    .localization(
        DependencyContainer.previewable.l10n,
    )
}
