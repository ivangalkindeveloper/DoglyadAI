import SwiftUI

public struct DStretchyHeader<Content: View>: View {
    private let height: CGFloat
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    private let content: Content

    public init(
        height: CGFloat,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content,
    ) {
        self.height = height
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.content = content()
    }

    public var body: some View {
        Group {
            GeometryReader { geometry in
                let stretch = max(
                    0,
                    geometry.frame(
                        in: .scrollView(
                            axis: .vertical,
                        ),
                    ).minY,
                )

                content
                    .frame(
                        width: geometry.size.width,
                        height: height + stretch,
                    )
                    .clipped()
                    .offset(
                        y: -stretch,
                    )
            }
            .frame(
                height: height,
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
