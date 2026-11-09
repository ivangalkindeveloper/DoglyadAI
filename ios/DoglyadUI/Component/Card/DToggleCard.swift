import SwiftUI

public struct DToggleCard: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let title: LocalizedStringResource
    private let description: LocalizedStringResource
    @Binding private var isOn: Bool
    private let action: () -> Void
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        title: LocalizedStringResource,
        description: LocalizedStringResource,
        isOn: Binding<Bool>,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = .combine,
        accessibilityIdentifier: String? = nil,
    ) {
        self.title = title
        self.description = description
        _isOn = isOn
        self.action = action
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s4,
        ) {
            DCard(
                action: action,
                content: {
                    HStack {
                        DText(
                            title,
                        ).dStyle(
                            font: typography.linkSmall,
                        )

                        Spacer(
                            minLength: size.s16,
                        )

                        DToggle(
                            title,
                            isOn: $isOn,
                        )
                        .labelsHidden()
                        .toggleStyle(
                            .switch,
                        )
                        .allowsHitTesting(
                            false,
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading,
                    )
                    .foregroundStyle(
                        color.grayscaleHeader,
                    )
                },
                isDisabled: isDisabled,
                accessibilityElement: accessibilityElement,
                accessibilityIdentifier: accessibilityIdentifier,
                accessibilityTraits: isOn ? .isSelected : [],
            )

            DText(
                description,
            )
            .dStyle(
                font: typography.textXSmall,
                color: color.grayscalePlacehold,
            )
            .padding(
                .horizontal,
                size.s8,
            )
        }
    }
}
