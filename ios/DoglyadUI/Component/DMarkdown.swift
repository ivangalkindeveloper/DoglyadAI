internal import MarkdownUI
import SwiftUI

public struct DMarkdown: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }

    private let content: String
    private let textColor: Color?

    public init(
        content: String,
        textColor: Color? = nil
    ) {
        self.content = content
        self.textColor = textColor
    }

    public var body: some View {
        let primary = textColor ?? color.grayscaleHeader
        let blockquoteText = textColor == nil ? color.grayscaleBody : primary.opacity(0.9)
        let headingSixText = textColor == nil ? color.grayscaleLabel : primary.opacity(0.82)
        Markdown(content)
            .markdownTheme(
                Self.doglyadTheme(
                    color: color,
                    primaryText: primary,
                    blockquoteText: blockquoteText,
                    headingSixText: headingSixText
                )
            )
            .tint(color.primaryDefaultWeak)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sizes and typefaces match `DTypography.shared` and `DFontFamily`.
    private static func doglyadTheme(
        color: DColor,
        primaryText: Color,
        blockquoteText: Color,
        headingSixText: Color
    ) -> Theme {
        Theme.basic
            .text {
                FontProperties(
                    family: .custom(DFontFamily.MontserratRegular.rawValue),
                    style: .normal,
                    weight: .regular,
                    size: 16
                )
                ForegroundColor(primaryText)
            }
            .strong {
                FontProperties(
                    family: .custom(DFontFamily.MontserratSemiBold.rawValue),
                    weight: .regular,
                    size: 14
                )
                ForegroundColor(primaryText)
            }
            .emphasis {
                FontProperties(
                    family: .custom(DFontFamily.MontserratRegular.rawValue),
                    style: .italic,
                    weight: .regular,
                    size: 14
                )
                ForegroundColor(primaryText)
            }
            .strikethrough {
                StrikethroughStyle(.single)
                ForegroundColor(color.grayscalePlacehold)
            }
            .link {
                FontProperties(
                    family: .custom(DFontFamily.MontserratSemiBold.rawValue),
                    weight: .regular,
                    size: 16
                )
                ForegroundColor(color.primaryDefaultWeak)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.92))
                ForegroundColor(primaryText)
                BackgroundColor(color.primaryDefaultStrong.opacity(0.14))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownMargin(top: .rem(1.5), bottom: .rem(1))
                    .markdownTextStyle {
                        FontProperties(
                            family: .custom(DFontFamily.MontserratBold.rawValue),
                            weight: .regular,
                            size: 24
                        )
                        ForegroundColor(primaryText)
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .markdownMargin(top: .rem(1.5), bottom: .rem(1))
                    .markdownTextStyle {
                        FontProperties(
                            family: .custom(DFontFamily.MontserratBold.rawValue),
                            weight: .regular,
                            size: 20
                        )
                        ForegroundColor(primaryText)
                    }
            }
            .heading3 { configuration in
                configuration.label
                    .markdownMargin(top: .rem(1.5), bottom: .rem(1))
                    .markdownTextStyle {
                        FontProperties(
                            family: .custom(DFontFamily.MontserratSemiBold.rawValue),
                            weight: .regular,
                            size: 17
                        )
                        ForegroundColor(primaryText)
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .markdownMargin(top: .rem(1.5), bottom: .rem(1))
                    .markdownTextStyle {
                        FontProperties(
                            family: .custom(DFontFamily.MontserratSemiBold.rawValue),
                            weight: .regular,
                            size: 14
                        )
                        ForegroundColor(primaryText)
                    }
            }
            .heading5 { configuration in
                configuration.label
                    .markdownMargin(top: .rem(1.5), bottom: .rem(1))
                    .markdownTextStyle {
                        FontProperties(
                            family: .custom(DFontFamily.MontserratSemiBold.rawValue),
                            weight: .regular,
                            size: 13
                        )
                        ForegroundColor(primaryText)
                    }
            }
            .heading6 { configuration in
                configuration.label
                    .markdownMargin(top: .rem(1.5), bottom: .rem(1))
                    .markdownTextStyle {
                        FontProperties(
                            family: .custom(DFontFamily.MontserratMedium.rawValue),
                            weight: .regular,
                            size: 13
                        )
                        ForegroundColor(headingSixText)
                    }
            }
            .blockquote { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontProperties(
                            family: .custom(DFontFamily.MontserratRegular.rawValue),
                            style: .italic,
                            weight: .regular,
                            size: 14
                        )
                        ForegroundColor(blockquoteText)
                    }
                    .relativePadding(.leading, length: .em(2))
                    .relativePadding(.trailing, length: .em(1))
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.15))
                        .relativePadding(.leading, length: .rem(1))
                        .markdownTextStyle {
                            FontProperties(
                                family: .custom(DFontFamily.MontserratRegular.rawValue),
                                familyVariant: .monospaced,
                                weight: .regular,
                                size: 13
                            )
                            ForegroundColor(primaryText)
                            BackgroundColor(color.primaryBackgroundStrong.opacity(0.35))
                        }
                }
                .markdownMargin(top: .zero, bottom: .em(1))
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontProperties(
                                family: .custom(DFontFamily.MontserratSemiBold.rawValue),
                                weight: .regular,
                                size: 14
                            )
                        }
                        ForegroundColor(primaryText)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.15))
                    .relativePadding(.horizontal, length: .em(0.72))
                    .relativePadding(.vertical, length: .em(0.35))
            }
    }
}
