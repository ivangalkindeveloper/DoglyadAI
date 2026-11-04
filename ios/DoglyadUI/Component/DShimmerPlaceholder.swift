import SwiftUI

public struct DShimmerPlaceholder: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let cornerRadius: CGFloat?

    public init(
        cornerRadius: CGFloat? = nil,
    ) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(
            cornerRadius: cornerRadius ?? size.s16,
        )
        .fill(
            color.grayscaleLine.opacity(
                0.5,
            ),
        )
        .dShimmer(
            cornerRadius: cornerRadius ?? size.s16,
        )
    }
}
