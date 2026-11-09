import SwiftUI

public struct DCloseButton: DViewProtocol {
    public enum Style {
        case regular
        case destructive
    }

    @EnvironmentObject public var theme: DTheme
    let style: Style
    let action: () -> Void
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        style: Style = .regular,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.style = style

        self.action = action
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
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
                DTextButton(
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
    DCloseButton {
        print(
            "Close",
        )
    }
    .padding()
    .dThemeWrapper()
}
