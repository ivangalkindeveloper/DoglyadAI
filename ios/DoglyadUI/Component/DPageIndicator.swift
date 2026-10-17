import SwiftUI

public struct DPageIndicator: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let count: Int
    private let currentIndex: Int

    public init(
        count: Int,
        currentIndex: Int,
    ) {
        self.count = count
        self.currentIndex = currentIndex
    }

    public var body: some View {
        HStack(
            spacing: size.s4,
        ) {
            ForEach(
                0 ..< max(
                    count,
                    0,
                ),
                id: \.self,
            ) { index in
                Capsule()
                    .fill(
                        index <= currentIndex ? color.primaryDefault : color.grayscaleLine,
                    )
                    .frame(
                        height: size.s2,
                    )
            }
        }
        .accessibilityHidden(
            true,
        )
    }
}
