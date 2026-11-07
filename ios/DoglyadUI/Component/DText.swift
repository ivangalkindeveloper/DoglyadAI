import SwiftUI

public struct DText: View {
    private let text: Text
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ localized: LocalizedStringResource,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        text = Text(
            localized,
        )
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public init(
        _ string: String,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        text = Text(
            verbatim: string,
        )
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public init(
        _ attributed: AttributedString,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        text = Text(
            attributed,
        )
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            text
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}

public extension DText {
    func dStyle(
        font: Font? = nil,
        color: Color? = nil,
        alignment: TextAlignment? = nil,
    ) -> some View {
        modifier(
            DTextModifier(
                font: font,
                color: color,
                alignment: alignment,
            ),
        )
    }
}

private struct DTextModifier: ViewModifier {
    @EnvironmentObject private var theme: DTheme

    private var typography: DTypography {
        theme.typography
    }

    let font: Font?
    let color: Color?
    let alignment: TextAlignment?

    init(
        font: Font?,
        color: Color?,
        alignment: TextAlignment?,
    ) {
        self.font = font
        self.color = color
        self.alignment = alignment
    }

    func body(
        content: Content,
    ) -> some View {
        content
            .font(
                font ?? typography.textMedium,
            )
            .foregroundStyle(
                color ?? theme.color.grayscaleHeader,
            )
            .multilineTextAlignment(
                alignment ?? .leading,
            )
    }
}

#Preview {
    DText(
        "Hello, World!",
    )
    .dThemeWrapper()
}
