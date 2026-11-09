import SwiftUI

public struct DToolbarButton: DViewProtocol {
    public enum Style {
        case grayscaleHeader
        case primaryDefault
    }

    public enum Content {
        case icon(ImageResource)

        case text(LocalizedStringResource)
    }

    @EnvironmentObject public var theme: DTheme
    private let style: Style
    private let badge: DButtonBadge?
    private let content: Content
    private let action: () -> Void
    private let isDisabled: Bool
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        style: Style,
        badge: DButtonBadge? = nil,
        content: Content,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.style = style
        self.badge = badge
        self.content = content

        self.action = action
        self.isDisabled = isDisabled
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            Button(
                action: action,
            ) {
                buttonContent
            }
            .buttonStyle(
                .plain,
            )
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

    @ViewBuilder
    private var buttonContent: some View {
        if let badge {
            DBadge(
                badge.title,
                isVisible: badge.isVisible,
                isShimmering: badge.isShimmering,
            ) {
                styledLabel
            }
        } else {
            styledLabel
        }
    }

    private var styledLabel: some View {
        label
            .frame(
                minWidth: size.s40,
                minHeight: size.s40,
            )
            .background {
                background
            }
            .frame(
                minWidth: size.s48,
                minHeight: size.s48,
            )
            .contentShape(
                Rectangle(),
            )
    }

    @ViewBuilder
    private var label: some View {
        switch content {
        case let .icon(
            icon,
        ):
            DIcon(
                icon,
                color: foregroundColor,
            )
        case let .text(
            text,
        ):
            DText(
                text,
            )
            .dStyle(
                font: typography.linkSmall,
                color: foregroundColor,
            )
            .lineLimit(
                1,
            )
            .padding(
                .horizontal,
                size.s12,
            )
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .grayscaleHeader:
            color.grayscaleHeader
        case .primaryDefault:
            color.grayscaleBackground
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .grayscaleHeader:
            Capsule()
                .fill(
                    .ultraThinMaterial,
                )
        case .primaryDefault:
            Capsule()
                .fill(
                    color.gradientPrimaryWeak,
                )
        }
    }
}

#Preview {
    HStack(
        spacing: .zero,
    ) {
        DToolbarButton(
            style: .grayscaleHeader,
            badge: DButtonBadge(
                "Pro",
                isShimmering: true,
            ),
            content: .icon(
                .microphone,
            ),
            action: {},
        )

        DToolbarButton(
            style: .primaryDefault,
            content: .text(
                "Generate",
            ),
            action: {},
        )
    }
    .dThemeWrapper()
}
