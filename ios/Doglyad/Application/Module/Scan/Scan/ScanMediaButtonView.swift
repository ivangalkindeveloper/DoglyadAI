import DoglyadUI
import SwiftUI

struct ScanMediaButtonView: DView {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.isEnabled,
    ) private var isEnabled
    @EnvironmentObject var theme: DTheme

    let isCompact: Bool
    let action: () -> Void

    init(
        isCompact: Bool = false,
        action: @escaping () -> Void,
    ) {
        self.isCompact = isCompact
        self.action = action
    }

    var body: some View {
        DButtonCard(
            isPlain: true,
            action: action,
        ) {
            HStack(
                spacing: size.s8,
            ) {
                DIcon(
                    .import,
                    color: color.primaryDefault,
                    height: size.s24,
                )

                if !isCompact {
                    DText(
                        l10n[
                            .scanImportButton,
                        ],
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.primaryDefault,
                        alignment: .center,
                    )
                }
            }
            .padding(
                isCompact ? .zero : size.s16,
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
            )
            .background {
                DCardBackground(
                    cornerRadius: cornerRadius,
                    color: isEnabled ? color.grayscaleBackground : color.grayscaleInput,
                    borderColor: color.primaryDefault,
                    lineWidth: 1,
                    dash: [size.s8, size.s4],
                )
            }
        }
        .frame(
            width: isCompact ? compactButtonSize : nil,
            height: isCompact ? compactButtonSize : buttonHeight,
        )
        .if(
            isCompact,
        ) { view in
            view
                .padding(
                    .top,
                    size.s8,
                )
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

#Preview {
    VStack {
        ScanMediaButtonView(
            action: {},
        )

        ScanMediaButtonView(
            isCompact: true,
            action: {},
        )
    }
    .padding()
    .dThemeWrapper()
    .localization(
        DependencyContainer.previewable.l10n,
    )
}
