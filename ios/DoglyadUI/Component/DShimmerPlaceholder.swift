import SwiftUI

public struct DShimmerPlaceholder: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let cornerRadius: CGFloat?
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        cornerRadius: CGFloat? = nil,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.cornerRadius = cornerRadius
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            RoundedRectangle(
                cornerRadius: cornerRadius ?? size.s16,
            )
            .fill(
                color.grayscaleLine.opacity(
                    0.5,
                ),
            )
            .dShimmer(
                cornerRadius: cornerRadius ?? size.s16,
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
