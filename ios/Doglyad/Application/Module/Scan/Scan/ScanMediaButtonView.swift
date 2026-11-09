import DoglyadUI
import SwiftUI

struct ScanMediaButtonView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.isEnabled,
    ) private var isEnabled
    @EnvironmentObject var theme: DTheme
    let isCompact: Bool
    let action: () -> Void
    private let isDisabled: Bool

    init(
        isCompact: Bool = false,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
    ) {
        self.isCompact = isCompact
        self.action = action
        self.isDisabled = isDisabled
    }

    var body: some View {
        DTextButton(
            action: action,
            content: {
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
                        cornerRadius: size.cardCornerRadius,
                        color: isEnabled && !isDisabled ? color.grayscaleBackground : color.grayscaleInput,
                        borderColor: color.primaryDefault,
                        lineWidth: 1,
                        dash: [size.s8, size.s4],
                    )
                }
            },
            isDisabled: isDisabled,
            accessibilityIdentifier: "scan.importMedia",
        )

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
}
