import SwiftUI

public struct DCheck: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    @Environment(
        \.displayScale,
    ) private var displayScale
    private let isChecked: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        isChecked: Bool,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.isChecked = isChecked
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            Circle()
                .fill(
                    isChecked ? color.primaryDefault : .clear,
                )
                .overlay {
                    Circle().strokeBorder(
                        isChecked ? color.primaryDefault : color.grayscalePlacehold,
                        lineWidth: 1 / displayScale,
                    )
                }
                .overlay {
                    if isChecked {
                        DIcon(
                            .check,
                            color: color.grayscaleBackground,
                            height: size.s16,
                        )
                    }
                }
                .frame(
                    width: size.s24,
                    height: size.s24,
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
