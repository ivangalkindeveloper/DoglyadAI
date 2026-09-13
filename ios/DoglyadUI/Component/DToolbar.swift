import SwiftUI

public struct DToolbar: DView {
    @EnvironmentObject public var theme: DTheme

    private let upAccessibilityLabel: LocalizedStringResource
    private let downAccessibilityLabel: LocalizedStringResource
    private let doneAccessibilityLabel: LocalizedStringResource
    private let onTapUp: (() -> Void)?
    private let onTapDown: (() -> Void)?
    private let onTapDone: () -> Void

    public init(
        upAccessibilityLabel: LocalizedStringResource,
        downAccessibilityLabel: LocalizedStringResource,
        doneAccessibilityLabel: LocalizedStringResource,
        onTapUp: (() -> Void)? = nil,
        onTapDown: (() -> Void)? = nil,
        onTapDone: @escaping () -> Void
    ) {
        self.upAccessibilityLabel = upAccessibilityLabel
        self.downAccessibilityLabel = downAccessibilityLabel
        self.doneAccessibilityLabel = doneAccessibilityLabel
        self.onTapUp = onTapUp
        self.onTapDown = onTapDown
        self.onTapDone = onTapDone
    }

    public var body: some View {
        HStack(
            spacing: .zero
        ) {
            if let onTapUp {
                toolbarButton(
                    image: .up,
                    accessibilityLabel: upAccessibilityLabel,
                    action: onTapUp
                )
            }

            if let onTapDown {
                toolbarButton(
                    image: .down,
                    accessibilityLabel: downAccessibilityLabel,
                    action: onTapDown
                )
            }

            Spacer()

            toolbarButton(
                image: .check,
                accessibilityLabel: doneAccessibilityLabel,
                iconColor: color.grayscaleBackground,
                usesGradientBackground: true,
                action: onTapDone
            )
        }
        .padding(.horizontal, size.s8)
        .frame(
            maxWidth: .infinity,
            minHeight: size.s48
        )
    }

    private func toolbarButton(
        image: ImageResource,
        accessibilityLabel: LocalizedStringResource,
        iconColor: Color? = nil,
        usesGradientBackground: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            DIcon(
                image,
                color: iconColor ?? color.grayscaleHeader
            )
            .frame(
                width: size.s40,
                height: size.s40
            )
            .background {
                if usesGradientBackground {
                    Circle()
                        .fill(color.gradientPrimaryWeak)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
            }
            .frame(
                width: size.s48,
                height: size.s48
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
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
