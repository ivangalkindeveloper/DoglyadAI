import SwiftUI

public struct DToolbar: DView {
    @EnvironmentObject public var theme: DTheme

    private let upAccessibilityLabel: LocalizedStringResource
    private let downAccessibilityLabel: LocalizedStringResource
    private let doneAccessibilityLabel: LocalizedStringResource
    private let onTapUp: (() -> Void)?
    private let onTapDown: (() -> Void)?
    private let onTapDone: () -> Void
    private let trailButtons: [DToolbarButton]

    public init(
        upAccessibilityLabel: LocalizedStringResource,
        downAccessibilityLabel: LocalizedStringResource,
        doneAccessibilityLabel: LocalizedStringResource,
        onTapUp: (() -> Void)? = nil,
        onTapDown: (() -> Void)? = nil,
        onTapDone: @escaping () -> Void,
        trailButtons: [DToolbarButton] = []
    ) {
        self.upAccessibilityLabel = upAccessibilityLabel
        self.downAccessibilityLabel = downAccessibilityLabel
        self.doneAccessibilityLabel = doneAccessibilityLabel
        self.trailButtons = trailButtons
        self.onTapUp = onTapUp
        self.onTapDown = onTapDown
        self.onTapDone = onTapDone
    }

    public var body: some View {
        HStack(
            spacing: .zero
        ) {
            if let onTapUp {
                DToolbarButton(
                    accessibilityLabel: upAccessibilityLabel,
                    style: .grayscaleHeader,
                    content: .icon(.up),
                    action: onTapUp
                )
            }

            if let onTapDown {
                DToolbarButton(
                    accessibilityLabel: downAccessibilityLabel,
                    style: .grayscaleHeader,
                    content: .icon(.down),
                    action: onTapDown
                )
            }

            Spacer()

            DToolbarButton(
                accessibilityLabel: doneAccessibilityLabel,
                style: .grayscaleHeader,
                content: .icon(.check),
                action: onTapDone
            )

            ForEach(trailButtons.indices, id: \.self) { index in
                trailButtons[index]
            }
        }
        .padding(.horizontal, size.s8)
        .frame(
            maxWidth: .infinity,
            minHeight: size.s48
        )
    }
}

#Preview {
    DToolbar(
        upAccessibilityLabel: "Previous",
        downAccessibilityLabel: "Next",
        doneAccessibilityLabel: "Done",
        onTapUp: {},
        onTapDown: {},
        onTapDone: {}
    )
    .dThemeWrapper()
}
