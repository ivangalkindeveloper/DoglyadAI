import SwiftUI

public struct DShareLink<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let item: String
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    private let content: Content

    public init(
        item: String,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content,
    ) {
        self.item = item
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.content = content()
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
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
