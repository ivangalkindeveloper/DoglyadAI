import SwiftUI

public struct DShimmerTextLines: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let lineHeight: CGFloat
    private let lineWidths: [CGFloat]
    private let spacing: CGFloat
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        lineHeight: CGFloat,
        lineWidths: [CGFloat] = [0.9, 0.72, 0.84, 0.55],
        spacing: CGFloat = 0,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.lineHeight = lineHeight
        self.lineWidths = lineWidths
        self.spacing = spacing
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    private var contentHeight: CGFloat {
        CGFloat(
            lineWidths.count,
        ) * lineHeight + CGFloat(
            max(
                lineWidths.count - 1,
                0,
            ),
        ) * spacing
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(
                alignment: .leading,
                spacing: spacing,
            ) {
                ForEach(
                    lineWidths.indices,
                    id: \.self,
                ) { index in
                    DShimmerPlaceholder(
                        cornerRadius: .infinity,
                    )
                    .frame(
                        width: geometry.size.width * min(
                            max(
                                lineWidths[
                                    index,
                                ],
                                0,
                            ),
                            1,
                        ),
                        height: lineHeight * 0.7,
                    )
                    .frame(
                        height: lineHeight,
                        alignment: .center,
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading,
            )
        }
        .frame(
            height: contentHeight,
        )
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
    }
}

#Preview {
    DShimmerTextLines(
        lineHeight: 18,
    )
    .padding()
    .dThemeWrapper()
}
