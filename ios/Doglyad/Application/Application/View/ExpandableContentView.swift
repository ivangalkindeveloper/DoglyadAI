import DoglyadUI
import SwiftUI
import UIKit

struct ExpandableContentView<Content: View>: DViewProtocol {
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
    private let isDisabled: Bool

    init(
        text: String,
        backgroundColor: Color,
        collapsedLineLimit: Int,
        collapsedFontSize: CGFloat = 16,
        collapsedLineSpacing: CGFloat = 16 * 0.15,
        onTapContent: (() -> Void)?,
        @ViewBuilder content: () -> Content,
        isDisabled: Bool = false,
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.collapsedLineLimit = collapsedLineLimit
        self.collapsedFontSize = collapsedFontSize
        self.collapsedLineSpacing = collapsedLineSpacing
        self.onTapContent = onTapContent
        self.content = content()
        self.isDisabled = isDisabled
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
            ExpandableContentTapView(
                content: content,
                onTapContent: onTapContent,
                isDisabled: isDisabled,
            )
            .fixedSize(
                horizontal: false,
                vertical: true,
            )
            .onGeometryChange(
                for: CGFloat.self,
                of: {
                    $0.size.height
                },
                action: {
                    contentHeight = $0
                },
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

                        ExpandableContentButtonView(
                            isExpanded: $isExpanded,
                            isShowingExpandedContent: isShowingExpandedContent,
                            isDisabled: isDisabled,
                        )
                        .background(
                            backgroundColor,
                        )
                    }
                }
            }

            if isShowingExpandedContent {
                ExpandableContentButtonView(
                    isExpanded: $isExpanded,
                    isShowingExpandedContent: isShowingExpandedContent,
                    isDisabled: isDisabled,
                )
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
}

private struct ExpandableContentButtonView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @Binding private var isExpanded: Bool
    private let isShowingExpandedContent: Bool
    private let isDisabled: Bool

    init(
        isExpanded: Binding<Bool>,
        isShowingExpandedContent: Bool,
        isDisabled: Bool,
    ) {
        _isExpanded = isExpanded
        self.isShowingExpandedContent = isShowingExpandedContent
        self.isDisabled = isDisabled
    }

    var body: some View {
        DTextButton(
            action: {
                withAnimation(
                    theme.animation,
                ) {
                    isExpanded.toggle()
                }
            },
            content: {
                DText(
                    l10n[
                        isShowingExpandedContent ? .buttonCollapse : .buttonExpand,
                    ],
                )
                .dStyle(
                    font: typography.linkSmall,
                    color: color.primaryDefault,
                )
            },
            isDisabled: isDisabled,
        )
    }
}

private struct ExpandableContentTapView<Content: View>: View {
    private let content: Content
    private let onTapContent: (() -> Void)?
    private let isDisabled: Bool

    init(
        content: Content,
        onTapContent: (() -> Void)?,
        isDisabled: Bool,
    ) {
        self.content = content
        self.onTapContent = onTapContent
        self.isDisabled = isDisabled
    }

    var body: some View {
        if let onTapContent {
            DTextButton(
                action: onTapContent,
                content: {
                    ExpandableContentAlignedView(
                        content: content,
                    )
                },
                isDisabled: isDisabled,
            )
        } else {
            ExpandableContentAlignedView(
                content: content,
            )
        }
    }
}

private struct ExpandableContentAlignedView<Content: View>: View {
    private let content: Content

    init(
        content: Content,
    ) {
        self.content = content
    }

    var body: some View {
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
