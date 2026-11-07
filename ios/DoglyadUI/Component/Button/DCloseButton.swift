import SwiftUI

public struct DCloseButton: DViewProtocol {
    public enum Style {
        case regular
        case destructive
    }

    @EnvironmentObject public var theme: DTheme

    let style: Style
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?
    let action: () -> Void

    public init(
        style: Style = .regular,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
    ) {
        self.style = style
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.action = action
    }

    public var body: some View {
        Group {
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
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
            ),
        )
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
