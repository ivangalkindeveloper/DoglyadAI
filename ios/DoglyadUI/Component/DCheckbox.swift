import SwiftUI

public struct DCheckbox: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    @Binding var isChecked: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        isChecked: Binding<Bool>,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        _isChecked = isChecked
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            Button {
                isChecked.toggle()
            } label: {
                RoundedRectangle(
                    cornerRadius: size.s4,
                )
                .fill(
                    isChecked ? color.primaryDefault : .clear,
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: size.s4,
                    )
                    .stroke(
                        isChecked ? color.primaryDefault : color.grayscalePlacehold,
                        lineWidth: 1.5,
                    ),
                )
                .overlay {
                    if isChecked {
                        Image(
                            systemName: "checkmark",
                        )
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: size.s10,
                            height: size.s10,
                        )
                        .foregroundColor(
                            color.grayscaleBackground,
                        )
                        .fontWeight(
                            .bold,
                        )
                    }
                }
                .frame(
                    width: size.s24,
                    height: size.s24,
                )
            }
            .buttonStyle(
                .plain,
            )
            .contentShape(
                Rectangle().inset(
                    by: -size.s12,
                ),
            )
            .animation(
                theme.animation,
                value: isChecked,
            )
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
    @Previewable @State var isChecked = false

    HStack {
        DCheckbox(
            isChecked: $isChecked,
        )

        Text(
            "Accept terms",
        )
    }
    .padding()
    .dThemeWrapper()
}
