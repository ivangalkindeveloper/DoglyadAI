import SwiftUI

public struct DCard<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    @Environment(
        \.isEnabled,
    ) private var isEnabled
    let action: () -> Void
    let content: () -> Content
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?
    private let accessibilityTraits: AccessibilityTraits?

    public init(
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityTraits: AccessibilityTraits? = nil,
    ) {
        self.action = action
        self.content = content
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityTraits = accessibilityTraits
    }

    public var body: some View {
        Button(
            action: action,
        ) {
            content()
                .padding(
                    size.s14,
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: size.s48,
                )
                .foregroundStyle(
                    isEnabled && !isDisabled ? color.grayscaleHeader : color.grayscalePlacehold,
                )
                .progressViewStyle(
                    CircularProgressViewStyle(
                        tint: isEnabled && !isDisabled ? color.grayscaleHeader : color.grayscalePlacehold,
                    ),
                )
                .background(
                    DCardBackground(
                        cornerRadius: size.cardCornerRadius,
                        color: color.grayscaleBackground,
                    ),
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: size.cardCornerRadius,
                    ),
                )
        }
        .buttonStyle(
            .plain,
        )
        .disabled(
            isDisabled,
        )
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
        DCard(
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

        DCard(
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
