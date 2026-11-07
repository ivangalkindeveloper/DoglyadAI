import SwiftUI

/// Progress with a known total. Indeterminate content loading uses shimmer.
public struct DProgress: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let value: Double
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        value: Double,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.value = value
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            ProgressView(
                value: min(
                    max(
                        value,
                        0,
                    ),
                    1,
                ),
            )
            .tint(
                color.primaryDefault,
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
