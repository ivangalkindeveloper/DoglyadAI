import DoglyadUI
import SwiftUI
import UIKit

struct ExpandableContentView<Content: View>: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    private let text: String
    private let backgroundColor: Color
    private let collapsedLineLimit: Int
    private let collapsedFontSize: CGFloat
    private let collapsedLineSpacing: CGFloat
    private let onTapContent: (() -> Void)?
    private let content: Content

    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int,
        collapsedFontSize: CGFloat = 16,
        collapsedLineSpacing: CGFloat = 16 * 0.15,
        onTapContent: (() -> Void)?,
        @ViewBuilder content: () -> Content,
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
        self.collapsedFontSize = collapsedFontSize
        self.collapsedLineSpacing = collapsedLineSpacing
        self.onTapContent = onTapContent
        self.content = content()
    }

    private var collapsedHeight: CGFloat {
        let font = UIFont(
            name: DFontFamily.MontserratRegular.rawValue,
            size: collapsedFontSize,
        ) ?? UIFont.systemFont(
            ofSize: collapsedFontSize,
        )
        let lineCount = CGFloat(
            max(
                1,
                collapsedLineLimit,
            ),
        )
        return ceil(
            font.lineHeight * lineCount + collapsedLineSpacing * (lineCount - 1),
        )
    }

    private var isExpandable: Bool {
        contentHeight > collapsedHeight + 0.5
    }

    private var isShowingExpandedContent: Bool {
        isExpanded && isExpandable
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s4,
        ) {
            tappableContent
                .fixedSize(
                    horizontal: false,
                    vertical: true,
                )
                .onGeometryChange(
                    for: CGFloat.self,
                    of: { $0.size.height },
                    action: { contentHeight = $0 },
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: isExpandable && !isShowingExpandedContent ? collapsedHeight : nil,
                    alignment: .topLeading,
                )
                .clipped()
                .overlay(
                    alignment: .bottomTrailing,
                ) {
                    if isExpandable, !isShowingExpandedContent {
                        HStack(
                            spacing: .zero,
                        ) {
                            DTextFade(
                                backgroundColor: backgroundColor,
                            )

                            expandButton
                                .background(
                                    backgroundColor,
                                )
                        }
                    }
                }

            if isShowingExpandedContent {
                expandButton
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing,
                    )
            }
        }
        .onChange(
            of: text,
        ) {
            isExpanded = false
        }
    }

    private var expandButton: some View {
        DButtonCard(
            isPlain: true,
            action: {
                withAnimation(
                    theme.animation,
                ) {
                    isExpanded.toggle()
                }
            },
        ) {
            DText(
                l10n[
                    isShowingExpandedContent ? .buttonCollapse : .buttonExpand,
                ],
            )
            .dStyle(
                font: typography.linkSmall,
                color: color.primaryDefault,
            )
        }
    }

    @ViewBuilder
    private var tappableContent: some View {
        if let onTapContent {
            DButtonCard(
                isPlain: true,
                action: onTapContent,
            ) {
                alignedContent
            }
            .buttonStyle(
                .plain,
            )
        } else {
            alignedContent
        }
    }

    private var alignedContent: some View {
        content
            .frame(
                maxWidth: .infinity,
                alignment: .leading,
            )
            .contentShape(
                Rectangle(),
            )
    }
}

#if DEBUG
    private struct ExpandableContentPreviewView: DViewProtocol {
        @EnvironmentObject var theme: DTheme

        private let fixture: ExpandableContentPreviewFixture
        let scenario: ExpandableContentPreviewFixture.Scenario

        init(
            scenario: ExpandableContentPreviewFixture.Scenario,
        ) {
            fixture = ExpandableContentPreviewFixture(
                scenario: scenario,
            )
            self.scenario = scenario
        }

        var body: some View {
            ExpandableContentView(
                text: fixture.text,
                backgroundColor: color.grayscaleInput,
                collapsedLineLimit: fixture.collapsedLineLimit,
                onTapContent: nil,
            ) {
                if fixture.isMarkdown {
                    DMarkdown(
                        content: fixture.text,
                    )
                } else {
                    DText(
                        fixture.text,
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
            .id(
                scenario,
            )
            .padding(
                size.s16,
            )
            .frame(
                width: fixture.width,
                alignment: .leading,
            )
            .background {
                DCardBackground(
                    cornerRadius: size.s16,
                    color: color.grayscaleInput,
                )
            }
            .padding(
                size.s16,
            )
        }
    }

    #Preview(
        "Одна строка — лимит 3",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .short,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "Три строки — лимит 3",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .threeLines,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "Четыре строки — лимит 3",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .fourLines,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "Длинный текст — ширина 360",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .long,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "Длинный текст — ширина 260",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .narrow,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "Длинный текст — лимит 1",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .singleLineLimit,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }

    #Preview(
        "Markdown — лимит 3",
        traits: .sizeThatFitsLayout,
    ) {
        ExpandableContentPreviewView(
            scenario: .markdown,
        )
        .dThemeWrapper()
        .localization(
            L10NPreviewFactory.make(),
        )
    }
#endif
