import SwiftUI

public struct DListButtonCard: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    let image: ImageResource?
    let title: LocalizedStringResource
    let description: LocalizedStringResource?
    let action: () -> Void
    let isSelected: Bool
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        image: ImageResource? = nil,
        title: LocalizedStringResource,
        description: LocalizedStringResource? = nil,
        action: @escaping () -> Void,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.image = image
        self.title = title
        self.description = description
        self.action = action
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            DCard(
                action: action,
                content: {
                    HStack(
                        alignment: .top,
                        spacing: .zero,
                    ) {
                        if let image {
                            Image(
                                image,
                            )
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: size.s48,
                                height: size.s48,
                            )
                            .padding(
                                .trailing,
                                size.s8,
                            )
                        }

                        VStack(
                            alignment: .leading,
                            spacing: .zero,
                        ) {
                            HStack(
                                alignment: .top,
                                spacing: .zero,
                            ) {
                                DText(
                                    title,
                                )
                                .dStyle(
                                    font: typography.linkSmall,
                                )

                                Spacer()
                                if isSelected {
                                    DIcon(
                                        .check,
                                        color: color.successDefault,
                                    )
                                    .padding(
                                        .leading,
                                        size.s16,
                                    )
                                }
                            }
                            if let description {
                                DText(
                                    description,
                                )
                                .dStyle(
                                    font: typography.textXSmall,
                                    color: color.grayscalePlacehold,
                                )
                                .padding(
                                    .top,
                                    size.s4,
                                )
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .top,
                        )
                    }
                },
                isDisabled: isDisabled,
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
    DListButtonCard(
        title: "Thyroid gland",
        action: {},
        isSelected: true,
    )
    .padding()
    .dThemeWrapper()
}
