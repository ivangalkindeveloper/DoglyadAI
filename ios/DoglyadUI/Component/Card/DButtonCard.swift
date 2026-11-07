import SwiftUI

public struct DButtonCard<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    let backgroundColor: Color?
    let isPlain: Bool
    let style: DButtonStyleType
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?
    private let accessibilityTraits: AccessibilityTraits?

    let action: () -> Void
    let content: () -> Content

    public init(
        backgroundColor: Color? = nil,
        isPlain: Bool = false,
        style: DButtonStyleType = .card,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityTraits: AccessibilityTraits? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.backgroundColor = backgroundColor
        self.isPlain = isPlain
        self.style = style
        self.content = content
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityTraits = accessibilityTraits

        self.action = action
    }

    public var body: some View {
        Group {
            Button(
                action: action,
            ) {
                content()
            }
            .if(
                isPlain,
            ) { view in
                view.buttonStyle(
                    .plain,
                )
            }
            .if(
                !isPlain,
            ) { view in
                view.buttonStyle(
                    DButtonStyle(
                        style,
                        backgroundColor: backgroundColor,
                    ),
                )
            }
        }
        .modifier(
            DAccessibilityModifier(
                element: accessibilityElement,
                identifier: accessibilityIdentifier,
                traits: accessibilityTraits,
            ),
        )
    }
}

#Preview {
    VStack(
        spacing: 16,
    ) {
        DButtonCard(
            action: {
                print(
                    "Tap",
                )
            },
        ) {
            HStack {
                DIcon(
                    .alertInfo,
                )

                DText(
                    "Button card",
                )
                .dStyle()

                Spacer()
            }
        }

        DButtonCard(
            action: {
                print(
                    "Tap",
                )
            },
        ) {
            DText(
                "Simple card",
            )
            .dStyle()
        }
    }
    .padding()
    .dThemeWrapper()
}
