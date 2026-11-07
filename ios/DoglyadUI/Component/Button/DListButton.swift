import SwiftUI

public struct DListButton: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    @Environment(
        \.isEnabled,
    ) private var isEnabled

    private let icon: ImageResource
    private let title: LocalizedStringResource
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    private let action: (() -> Void)?
    private let shareItem: String?
    private let isLoading: Bool
    private let isDisabled: Bool

    public init(
        icon: ImageResource,
        title: LocalizedStringResource,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        isDisabled: Bool = false,
    ) {
        self.icon = icon
        self.title = title
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.action = action
        shareItem = nil
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    public init(
        icon: ImageResource,
        title: LocalizedStringResource,
        shareItem: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.icon = icon
        self.title = title
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        action = nil
        self.shareItem = shareItem
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    public var body: some View {
        Group {
            let foregroundColor = isEnabled && !isLoading && !isDisabled ? color.grayscaleHeader : color.grayscalePlacehold

            HStack(
                spacing: size.s8,
            ) {
                DIcon(
                    icon,
                    color: foregroundColor,
                )

                DText(
                    String(
                        localized: title,
                    ),
                )
                .dStyle(
                    font: typography.linkSmall,
                    color: foregroundColor,
                    alignment: .leading,
                )
                .lineLimit(
                    1,
                )
                .truncationMode(
                    .middle,
                )

                Spacer()

                if isLoading {
                    ProgressView()
                        .frame(
                            width: size.s20,
                            height: size.s20,
                        )
                }
            }
            .ifLet(
                action,
            ) { label, action in
                DButtonCard(
                    action: action,
                ) {
                    label
                }
            }
            .ifLet(
                shareItem,
            ) { label, item in
                DShareLink(
                    item: item,
                ) {
                    label
                }
            }
            .disabled(
                isDisabled || isLoading,
            )
            .animation(
                theme.animation,
                value: isLoading,
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

#Preview(
    "01 DListButton",
) {
    VStack {
        DListButton(
            icon: .send,
            title: "Отправить",
            action: {},
        )

        DListButton(
            icon: .send,
            title: "Отправить",
            action: {},
            isLoading: true,
        )

        DListButton(
            icon: .send,
            title: "Отправить",
            action: {},
            isDisabled: true,
        )
    }
    .padding()
    .dThemeWrapper()
}
