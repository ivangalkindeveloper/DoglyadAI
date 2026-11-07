import SwiftUI

public struct DToolbar: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    private let onTapUp: (() -> Void)?
    private let onTapDown: (() -> Void)?
    private let onTapDone: () -> Void
    private let trailButtons: [DToolbarButton]

    public init(
        onTapUp: (() -> Void)? = nil,
        onTapDown: (() -> Void)? = nil,
        onTapDone: @escaping () -> Void,
        trailButtons: [DToolbarButton] = [],
    ) {
        self.trailButtons = trailButtons
        self.onTapUp = onTapUp
        self.onTapDown = onTapDown
        self.onTapDone = onTapDone
    }

    public var body: some View {
        HStack(
            spacing: .zero,
        ) {
            if let onTapUp {
                DToolbarButton(
                    style: .grayscaleHeader,
                    content: .icon(
                        .up,
                    ),
                    action: onTapUp,
                )
            }

            if let onTapDown {
                DToolbarButton(
                    style: .grayscaleHeader,
                    content: .icon(
                        .down,
                    ),
                    action: onTapDown,
                )
            }

            Spacer()

            DToolbarButton(
                style: .grayscaleHeader,
                content: .icon(
                    .check,
                ),
                action: onTapDone,
            )
            .accessibilityIdentifier(
                "keyboard.done",
            )

            ForEach(
                trailButtons.indices,
                id: \.self,
            ) { index in
                trailButtons[
                    index,
                ]
            }
        }
        .padding(
            .horizontal,
            size.s8,
        )
        .frame(
            maxWidth: .infinity,
            minHeight: size.s48,
        )
    }
}

#Preview {
    DToolbar(
        onTapUp: {},
        onTapDown: {},
        onTapDone: {},
    )
    .dThemeWrapper()
}
