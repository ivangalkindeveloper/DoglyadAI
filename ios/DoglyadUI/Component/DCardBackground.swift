import SwiftUI

public struct DCardBackground: View {
    private let cornerRadius: CGFloat
    private let color: Color
    private let gradient: LinearGradient?
    private let material: Material?
    private let borderColor: Color
    private let lineWidth: CGFloat
    private let dash: [CGFloat]
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        cornerRadius: CGFloat,
        color: Color = .clear,
        gradient: LinearGradient? = nil,
        material: Material? = nil,
        borderColor: Color = .clear,
        lineWidth: CGFloat = 0,
        dash: [CGFloat] = [],
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.cornerRadius = cornerRadius
        self.color = color
        self.gradient = gradient
        self.material = material
        self.borderColor = borderColor
        self.lineWidth = lineWidth
        self.dash = dash
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            RoundedRectangle(
                cornerRadius: cornerRadius,
            )
            .fill(
                gradient.map {
                    AnyShapeStyle(
                        $0,
                    )
                } ?? AnyShapeStyle(
                    color,
                ),
            )
            .overlay {
                if let material {
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                    ).fill(
                        material,
                    )
                }
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                )
                .strokeBorder(
                    borderColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        dash: dash,
                    ),
                )
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
