import DoglyadUI
import SwiftUI

struct ScanMediaButtonView: DView {
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
        DButtonCard(
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
                maxWidth: isCompact ? nil : .infinity
            )
        }
        .frame(
            width: isCompact ? compactButtonSize : nil,
            height: isCompact ? compactButtonSize : buttonHeight
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: cornerRadius
            )
            .stroke(
                color.primaryDefault,
                style: StrokeStyle(
                    lineWidth: 1,
                    lineCap: .round,
                    dash: [size.s8, size.s4]
                )
            )
        }
        .if(isCompact) { view in
            view
                .padding(.top, size.s8)
                .padding(.trailing, size.s8)
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
