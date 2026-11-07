import SwiftUI

public struct DToggleCard: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let title: LocalizedStringResource
    private let description: LocalizedStringResource
    @Binding private var isOn: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?
    private let action: () -> Void

    public init(
        title: LocalizedStringResource,
        description: LocalizedStringResource,
        isOn: Binding<Bool>,
        accessibilityElement: AccessibilityChildBehavior? = .combine,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.description = description
        _isOn = isOn
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s4,
        ) {
            DButtonCard(
                accessibilityElement: accessibilityElement,
                accessibilityIdentifier: accessibilityIdentifier,
                accessibilityTraits: isOn ? .isSelected : [],
                action: action,
            ) {
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
            }

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
