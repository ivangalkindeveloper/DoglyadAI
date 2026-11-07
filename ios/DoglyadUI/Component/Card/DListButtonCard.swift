import SwiftUI

public struct DListButtonCard: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    let image: ImageResource?
    let title: LocalizedStringResource
    let description: LocalizedStringResource?
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    let action: () -> Void
    let isSelected: Bool

    public init(
        image: ImageResource? = nil,
        title: LocalizedStringResource,
        description: LocalizedStringResource? = nil,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
        isSelected: Bool = false,
    ) {
        self.image = image
        self.title = title
        self.description = description
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.action = action
        self.isSelected = isSelected
    }

    public var body: some View {
        Group {
            DButtonCard(
                action: action,
            ) {
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
    DListButtonCard(
        title: "Thyroid gland",
        action: {},
        isSelected: true,
    )
    .padding()
    .dThemeWrapper()
}
