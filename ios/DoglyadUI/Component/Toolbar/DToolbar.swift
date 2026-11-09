import SwiftUI

public struct DToolbar: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let onTapUp: (() -> Void)?
    private let onTapDown: (() -> Void)?
    private let onTapDone: () -> Void
    private let trailButtons: [DToolbarButton]
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        onTapUp: (() -> Void)? = nil,
        onTapDown: (() -> Void)? = nil,
        onTapDone: @escaping () -> Void,
        trailButtons: [DToolbarButton] = [],
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.onTapUp = onTapUp
        self.onTapDown = onTapDown
        self.onTapDone = onTapDone
        self.trailButtons = trailButtons
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
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
                    accessibilityIdentifier: "keyboard.done",
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
        .disabled(
            isDisabled,
        )
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
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
