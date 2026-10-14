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
    DShimmerPreviewSurface(
        label: "Premium card",
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
        DShimmerPreviewSurface(
            label: "cornerRadius 0",
            cornerRadius: 0,
        )
        DShimmerPreviewSurface(
            label: "cornerRadius 0",
            cornerRadius: 0,
        )
        .dShimmer(
            cornerRadius: 0,
        )

        DShimmerPreviewSurface(
            label: "cornerRadius 12",
            cornerRadius: 12,
        )
        .dShimmer(
            cornerRadius: 12,
        )

        DShimmerPreviewSurface(
            label: "cornerRadius 28",
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
