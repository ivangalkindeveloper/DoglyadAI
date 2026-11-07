import SwiftUI

public struct DTextFade: View {
    private let backgroundColor: Color
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        backgroundColor: Color,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.backgroundColor = backgroundColor
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [backgroundColor.opacity(
                            0,
                        ), backgroundColor],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .frame(
                    width: 100,
                    height: 16,
                )
                .allowsHitTesting(
                    false,
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
