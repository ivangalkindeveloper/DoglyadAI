import DoglyadUI
import SwiftUI

struct ScanMediaButtonView: DView {
    @Environment(\.isEnabled) private var isEnabled
    @EnvironmentObject var theme: DTheme

    let isCompact: Bool
    let action: () -> Void

    init(
        isCompact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.isCompact = isCompact
        self.action = action
    }

    var body: some View {
        Button(
            action: action
        ) {
            HStack(
                spacing: size.s8
            ) {
                DIcon(
                    .import,
                    color: color.primaryDefault,
                    height: size.s24
                )

                if !isCompact {
                    DText(.scanImportButtonTitle)
                        .dStyle(
                            font: typography.linkSmall,
                            color: color.primaryDefault,
                            alignment: .center
                        )
                }
            }
            .padding(isCompact ? .zero : size.s16)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .background {
                RoundedRectangle(
                    cornerRadius: cornerRadius
                )
                .fill(
                    isEnabled ? color.grayscaleBackground : color.grayscaleInput
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius
                )
                .strokeBorder(
                    color.primaryDefault,
                    style: StrokeStyle(
                        lineWidth: 1,
                        lineCap: .round,
                        dash: [size.s8, size.s4]
                    )
                )
            }
        }
        .buttonStyle(ScanMediaButtonStyle())
        .frame(
            width: isCompact ? compactButtonSize : nil,
            height: isCompact ? compactButtonSize : buttonHeight
        )
        .if(isCompact) { view in
            view
                .padding(.top, size.s8)
        }
    }

    private var compactButtonSize: CGFloat {
        size.s64
    }

    private var buttonHeight: CGFloat {
        size.s64 + size.s8
    }

    private var cornerRadius: CGFloat {
        isCompact ? size.adaptiveCornerRadius / 4 : size.adaptiveCardCornerRadius
    }
}

private struct ScanMediaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(
                .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}

#Preview {
    VStack {
        ScanMediaButtonView(
            action: {}
        )

        ScanMediaButtonView(
            isCompact: true,
            action: {}
        )
    }
    .padding()
    .dThemeWrapper()
}
