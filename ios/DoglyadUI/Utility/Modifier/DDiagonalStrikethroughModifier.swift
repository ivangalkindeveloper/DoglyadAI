import SwiftUI

struct DDiagonalStrikethroughModifier: ViewModifier {
    @EnvironmentObject private var theme: DTheme
    private let color: Color

    init(
        color: Color,
    ) {
        self.color = color
    }

    func body(
        content: Content,
    ) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Path { path in
                        path.move(
                            to: CGPoint(
                                x: 0,
                                y: geometry.size.height * 0.8,
                            ),
                        )

                        path.addLine(
                            to: CGPoint(
                                x: geometry.size.width,
                                y: geometry.size.height * 0.2,
                            ),
                        )
                    }
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: theme.size.s1,
                            lineCap: .round,
                        ),
                    )
                }
                .padding(
                    theme.size.s4,
                )
                .allowsHitTesting(
                    false,
                )
            }
    }
}
