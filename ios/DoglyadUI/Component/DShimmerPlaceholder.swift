import SwiftUI

public struct DShimmerPlaceholder: DView {
    @EnvironmentObject public var theme: DTheme
    private let cornerRadius: CGFloat?

    public init(
        cornerRadius: CGFloat? = nil,
    ) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(
            cornerRadius: cornerRadius ?? size.s8,
        )
        .fill(
            color.grayscaleLine,
        )
        .dShimmer(
            cornerRadius: cornerRadius ?? size.s8,
        )
        .accessibilityHidden(
            true,
        )
    }
}
