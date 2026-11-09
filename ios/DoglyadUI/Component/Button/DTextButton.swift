import SwiftUI

public struct DTextButton<Content: View>: View {
    private let action: () -> Void
    private let content: () -> Content
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?
    private let accessibilityTraits: AccessibilityTraits?

    public init(
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityTraits: AccessibilityTraits? = nil,
    ) {
        self.action = action
        self.content = content
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityTraits = accessibilityTraits
    }

    public var body: some View {
        Button(
            action: action,
        ) {
            content()
        }
        .buttonStyle(
            .plain,
        )
        .disabled(
            isDisabled,
        )
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
                traits: accessibilityTraits,
            ),
        )
    }
}

#Preview(
    "01 DTextButton",
) {
    DTextButton(
        action: {},
    ) {
        DText(
            "Текстовая кнопка",
        )
        .dStyle()
    }
    .padding()
    .dThemeWrapper()
}
