import SwiftUI

public struct DToolbarButton: DView {
    public enum Style {
        case grayscaleHeader
        case primaryDefault
    }

    public enum Content {
        case icon(ImageResource)
        case text(LocalizedStringResource)
    }

    @EnvironmentObject public var theme: DTheme

    private let accessibilityLabel: LocalizedStringResource
    private let style: Style
    private let badge: DButtonBadge?
    private let content: Content
    private let action: () -> Void

    public init(
        accessibilityLabel: LocalizedStringResource,
        style: Style,
        badge: DButtonBadge? = nil,
        content: Content,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.style = style
        self.badge = badge
        self.content = content
        self.action = action
    }

    public var body: some View {
        Button(
            action: action
        ) {
            buttonContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    @ViewBuilder
    private var buttonContent: some View {
        if let badge {
            DBadge(
                badge.title,
                isVisible: badge.isVisible,
                isShimmering: badge.isShimmering
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
                minHeight: size.s40
            )
            .background {
                background
            }
            .frame(
                minWidth: size.s48,
                minHeight: size.s48
            )
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var label: some View {
        switch content {
        case let .icon(icon):
            DIcon(
                icon,
                color: foregroundColor
            )
        case let .text(text):
            DText(text)
                .dStyle(
                    font: typography.linkSmall,
                    color: foregroundColor
                )
                .lineLimit(1)
                .padding(.horizontal, size.s12)
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
                .fill(.ultraThinMaterial)
        case .primaryDefault:
            Capsule()
                .fill(color.gradientPrimaryWeak)
        }
    }
}

#Preview {
    HStack(spacing: .zero) {
        DToolbarButton(
            accessibilityLabel: "Microphone",
            style: .grayscaleHeader,
            badge: DButtonBadge(
                "Pro",
                isShimmering: true
            ),
            content: .icon(.microphone),
            action: {}
        )

        DToolbarButton(
            accessibilityLabel: "Generate",
            style: .primaryDefault,
            content: .text("Generate"),
            action: {}
        )
    }
    .dThemeWrapper()
}
