import SwiftUI

public struct DAudioMeter: DView {
    @EnvironmentObject public var theme: DTheme
    private let level: Float
    private static let profile: [CGFloat] = [0.3, 0.55, 0.8, 1.0, 0.7, 0.85, 1.0, 0.75, 0.5, 0.3]

    public init(
        level: Float,
    ) {
        self.level = level
    }

    public var body: some View {
        let normalizedLevel = CGFloat(
            min(
                max(
                    level,
                    0,
                ),
                1,
            ),
        )
        HStack(
            spacing: size.s4,
        ) {
            ForEach(
                Array(
                    Self.profile.enumerated(),
                ),
                id: \.offset,
            ) { _, weight in
                Capsule()
                    .fill(
                        color.grayscaleBackgroundWeak,
                    )
                    .frame(
                        width: size.s4,
                        height: size.s4 + (size.s24 - size.s4) * weight * normalizedLevel,
                    )
            }
        }
        .frame(
            height: size.s24,
        )
        .animation(
            theme.animation,
            value: level,
        )
        .accessibilityHidden(
            true,
        )
    }
}
