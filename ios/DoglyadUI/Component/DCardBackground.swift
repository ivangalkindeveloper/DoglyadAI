import SwiftUI

public struct DCardBackground: View {
    private let cornerRadius: CGFloat
    private let color: Color
    private let material: Material?
    private let borderColor: Color
    private let lineWidth: CGFloat
    private let dash: [CGFloat]

    public init(
        cornerRadius: CGFloat,
        color: Color = .clear,
        material: Material? = nil,
        borderColor: Color = .clear,
        lineWidth: CGFloat = 0,
        dash: [CGFloat] = [],
    ) {
        self.cornerRadius = cornerRadius
        self.color = color
        self.material = material
        self.borderColor = borderColor
        self.lineWidth = lineWidth
        self.dash = dash
    }

    public var body: some View {
        RoundedRectangle(
            cornerRadius: cornerRadius,
        )
        .fill(
            color,
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
        .accessibilityHidden(
            true,
        )
    }
}
