internal import Shimmer
import SwiftUI

public struct DShimmerModifier: ViewModifier {
    let isShimmering: Bool
    let cornerRadius: CGFloat

    public init(
        isShimmering: Bool = true,
        cornerRadius: CGFloat = .infinity,
    ) {
        self.isShimmering = isShimmering
        self.cornerRadius = cornerRadius
    }

    public func body(
        content: Content,
    ) -> some View {
        content
            .overlay {
                Color.clear
                    .shimmering(
                        active: isShimmering,
                        animation: Animation.linear(
                            duration: 1.5,
                        )
                        .delay(
                            2.4,
                        )
                        .repeatForever(
                            autoreverses: false,
                        ),
                        gradient: Gradient(
                            colors: [
                                .clear,
                                .white.opacity(
                                    0.8,
                                ),
                                .clear,
                            ],
                        ),
                        bandSize: 0.8,
                        mode: .overlay(
                            blendMode: .overlay,
                        ),
                    )
                    .cornerRadius(
                        cornerRadius,
                    )
                    .allowsHitTesting(
                        false,
                    )
            }
    }
}

public extension View {
    func dShimmer(
        isShimmering: Bool = true,
        cornerRadius: CGFloat = .infinity,
    ) -> some View {
        modifier(
            DShimmerModifier(
                isShimmering: isShimmering,
                cornerRadius: cornerRadius,
            ),
        )
    }
}

private func shimmerSurface(
    _ label: String,
    cornerRadius: CGFloat,
    height: CGFloat = 56,
) -> some View {
    RoundedRectangle(
        cornerRadius: cornerRadius,
    )
    .fill(
        LinearGradient(
            colors: [.blue, .indigo],
            startPoint: .leading,
            endPoint: .trailing,
        ),
    )
    .frame(
        height: height,
    )
    .overlay {
        Text(
            label,
        )
        .font(
            .footnote.weight(
                .semibold,
            ),
        )
        .foregroundStyle(
            .white,
        )
    }
}

#Preview(
    "Chip (capsule)",
) {
    Text(
        "PRO",
    )
    .font(
        .footnote.weight(
            .bold,
        ),
    )
    .foregroundStyle(
        .white,
    )
    .padding(
        .horizontal,
        16,
    )
    .padding(
        .vertical,
        8,
    )
    .background(
        Capsule().fill(
            .blue,
        ),
    )
    .dShimmer()
    .padding()
}

#Preview(
    "Card",
) {
    shimmerSurface(
        "Premium card",
        cornerRadius: 24,
        height: 120,
    )
    .dShimmer(
        cornerRadius: 24,
    )
    .padding()
}

#Preview(
    "Corner radius comparison",
) {
    VStack(
        spacing: 24,
    ) {
        shimmerSurface(
            "cornerRadius 0",
            cornerRadius: 0,
        )
        shimmerSurface(
            "cornerRadius 0",
            cornerRadius: 0,
        )
        .dShimmer(
            cornerRadius: 0,
        )

        shimmerSurface(
            "cornerRadius 12",
            cornerRadius: 12,
        )
        .dShimmer(
            cornerRadius: 12,
        )

        shimmerSurface(
            "cornerRadius 28",
            cornerRadius: 28,
        )
        .dShimmer(
            cornerRadius: 28,
        )

        Capsule()
            .fill(
                LinearGradient(
                    colors: [.blue, .indigo],
                    startPoint: .leading,
                    endPoint: .trailing,
                ),
            )
            .frame(
                height: 56,
            )
            .overlay {
                Text(
                    "capsule (.infinity)",
                )
                .font(
                    .footnote.weight(
                        .semibold,
                    ),
                )
                .foregroundStyle(
                    .white,
                )
            }
            .dShimmer()
    }
    .padding()
}
