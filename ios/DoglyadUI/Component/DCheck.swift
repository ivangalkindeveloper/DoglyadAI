import SwiftUI

public struct DCheck: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    @Environment(
        \.displayScale,
    ) private var displayScale

    private let isChecked: Bool

    public init(
        isChecked: Bool,
    ) {
        self.isChecked = isChecked
    }

    public var body: some View {
        Circle()
            .fill(
                isChecked ? color.primaryDefault : .clear,
            )
            .overlay {
                Circle().strokeBorder(
                    isChecked ? color.primaryDefault : color.grayscalePlacehold,
                    lineWidth: 1 / displayScale,
                )
            }
            .overlay {
                if isChecked {
                    DIcon(
                        .check,
                        color: color.grayscaleBackground,
                        height: size.s16,
                    )
                }
            }
            .frame(
                width: size.s24,
                height: size.s24,
            )
    }
}
