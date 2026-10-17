import SwiftUI

/// Progress with a known total. Indeterminate content loading uses shimmer.
public struct DProgress: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let value: Double

    public init(
        value: Double,
    ) {
        self.value = value
    }

    public var body: some View {
        ProgressView(
            value: min(
                max(
                    value,
                    0,
                ),
                1,
            ),
        )
        .tint(
            color.primaryDefault,
        )
    }
}
