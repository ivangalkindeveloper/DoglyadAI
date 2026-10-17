import SwiftUI

public struct DTextFade: View {
    private let backgroundColor: Color

    public init(
        backgroundColor: Color,
    ) {
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [backgroundColor.opacity(
                        0,
                    ), backgroundColor],
                    startPoint: .leading,
                    endPoint: .trailing,
                ),
            )
            .frame(
                width: 100,
                height: 16,
            )
            .allowsHitTesting(
                false,
            )
            .accessibilityHidden(
                true,
            )
    }
}
