import DoglyadUI
import SwiftUI
import UIKit

struct ExpandableContentView<Content: View>: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    private let text: String
    private let backgroundColor: Color
    private let collapsedLineLimit: Int
    private let onTapContent: (() -> Void)?
    private let content: Content

    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int,
        onTapContent: (() -> Void)?,
        @ViewBuilder content: () -> Content,
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
        self.onTapContent = onTapContent
        self.content = content()
    }

    private var collapsedHeight: CGFloat {
        let fontSize: CGFloat = 16
        let font = UIFont(
            name: DFontFamily.MontserratRegular.rawValue,
            size: fontSize,
        ) ?? UIFont.systemFont(
            ofSize: fontSize,
        )
        let lineCount = CGFloat(
            max(
                1,
                collapsedLineLimit,
            ),
        )
        return ceil(
            font.lineHeight * lineCount + fontSize * 0.15 * (lineCount - 1),
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
