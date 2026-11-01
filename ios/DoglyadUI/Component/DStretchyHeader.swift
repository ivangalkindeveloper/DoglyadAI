import SwiftUI

public struct DStretchyHeader<Content: View>: View {
    private let height: CGFloat
    private let content: Content

    public init(
        height: CGFloat,
        @ViewBuilder content: () -> Content,
    ) {
        self.height = height
        self.content = content()
    }

    public var body: some View {
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
}
