import SwiftUI

public struct DShareLink<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let item: String
    private let content: Content
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        item: String,
        @ViewBuilder content: () -> Content,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.item = item

        self.content = content()
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            ShareLink(
                item: item,
            ) {
                content
            }
            .buttonStyle(
                DButtonStyle(
                    .card,
                ),
            )
        }
        .disabled(
            isDisabled,
        )
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
