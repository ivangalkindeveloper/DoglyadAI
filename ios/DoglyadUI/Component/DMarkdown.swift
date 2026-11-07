internal import MarkdownUI
import SwiftUI

public struct DMarkdown: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    private let content: String
    private let textColor: Color?
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        content: String,
        textColor: Color? = nil,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.content = content
        self.textColor = textColor
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            let primary = textColor ?? color.grayscaleHeader
            let blockquoteText = textColor == nil ? color.grayscaleBody : primary.opacity(
                0.9,
            )
            let headingSixText = textColor == nil ? color.grayscaleLabel : primary.opacity(
                0.82,
            )

            Markdown(
                content,
            )
            .markdownTheme(
                DMarkdownThemeFactory.make(
                    color: color,
                    primaryText: primary,
                    blockquoteText: blockquoteText,
                    headingSixText: headingSixText,
                ),
            )
            .tint(
                color.primaryDefaultWeak,
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading,
            )
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }

    /// Sizes and typefaces match `DTypography.shared` and `DFontFamily`.
}
