import SwiftUI

public struct DBadge<Content: View>: DView {
    @EnvironmentObject public var theme: DTheme

    let badges: [DBadgeItem]
    let content: () -> Content

    public init(
        _ title: LocalizedStringResource,
        isVisible: Bool = true,
        isShimmering: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        badges = [
            DBadgeItem(
                title,
                isVisible: isVisible,
                isShimmering: isShimmering
            ),
        ]
        self.content = content
    }

    public init(
        _ badges: [DBadgeItem],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.badges = badges
        self.content = content
    }

    public var body: some View {
        content()
            .overlay(alignment: .topTrailing) {
                if !visibleBadges.isEmpty {
                    HStack(spacing: size.s4) {
                        ForEach(visibleBadges.indices, id: \.self) { index in
                            let badge = visibleBadges[index]
                            badgeView(badge)
                                .if(badge.isShimmering) { $0.dShimmer() }
                        }
                    }
                    .offset(x: size.s10, y: -size.s10)
                }
            }
    }

    private var visibleBadges: [DBadgeItem] {
        badges.filter(\.isVisible)
    }

    private func badgeView(_ badge: DBadgeItem) -> some View {
        Text(badge.title)
            .font(typography.linkXSmall)
            .foregroundStyle(color.grayscaleBackground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, size.s8)
            .padding(.vertical, size.s2)
            .background(
                Capsule()
                    .fill(color.gradientPrimary)
            )
    }
}

#Preview {
    DScreen { _, _ in
        VStack(spacing: 32) {
            DBadge("New") {
                DButtonCard(
                    action: {}
                ) {
                    HStack {
                        DText("Card with badge")
                            .dStyle()
                        Spacer()
                    }
                }
            }

            DBadge("Pro", isShimmering: true) {
                DButtonCard(
                    action: {}
                ) {
                    HStack {
                        DText("Shimmering pro badge")
                            .dStyle()
                        Spacer()
                    }
                }
            }

            DBadge("Long badge title") {
                DText("Badge grows to the left")
                    .dStyle()
            }

            DBadge([
                DBadgeItem("Pro", isShimmering: true),
                DBadgeItem("Coming soon"),
            ]) {
                DText("Card with multiple badges")
                    .dStyle()
            }
        }
        .padding()
    }
    .dThemeWrapper()
}
