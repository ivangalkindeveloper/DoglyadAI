import SwiftUI

public struct DPageIndicator: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let count: Int
    private let currentIndex: Int
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        count: Int,
        currentIndex: Int,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.count = count
        self.currentIndex = currentIndex
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            HStack(
                spacing: size.s4,
            ) {
                ForEach(
                    0 ..< max(
                        count,
                        0,
                    ),
                    id: \.self,
                ) { index in
                    Capsule()
                        .fill(
                            index <= currentIndex ? color.primaryDefault : color.grayscaleLine,
                        )
                        .frame(
                            height: size.s2,
                        )
                }
            }
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}
