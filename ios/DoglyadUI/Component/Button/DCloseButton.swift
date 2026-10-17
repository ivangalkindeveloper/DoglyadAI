import SwiftUI

public struct DCloseButton: DViewProtocol {
    public enum Style { case regular, destructive }
    @EnvironmentObject public var theme: DTheme

    let action: () -> Void
    let style: Style

    public init(
        style: Style = .regular,
        action: @escaping () -> Void,
    ) {
        self.style = style
        self.action = action
    }

    public var body: some View {
        switch style {
        case .regular:
            Button {
                action()
            } label: {
                Image(
                    systemName: "xmark.circle.fill",
                )
                .font(
                    .system(
                        size: 22,
                    ),
                )
                .foregroundStyle(
                    color.grayscaleLine,
                )
            }
        case .destructive:
            DButtonCard(
                isPlain: true,
                action: action,
            ) {
                DIcon(
                    .close,
                    color: color.dangerDefault,
                    height: size.s16,
                )
                .frame(
                    width: size.s24,
                    height: size.s24,
                )
                .background(
                    Circle().fill(
                        color.dangerDefaultWeak,
                    ),
                )
            }
        }
    }
}

#Preview {
    DCloseButton {
        print(
            "Close",
        )
    }
    .padding()
    .dThemeWrapper()
}
