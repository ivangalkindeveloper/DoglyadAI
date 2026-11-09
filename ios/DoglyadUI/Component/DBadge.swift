import SwiftUI

public struct DBadge<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    let badges: [DBadgeItem]
    let content: () -> Content
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    public init(
        _ title: LocalizedStringResource,
        isVisible: Bool = true,
        isShimmering: Bool = false,
        @ViewBuilder content: @escaping () -> Content,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        badges = [
            DBadgeItem(
                title,
                isVisible: isVisible,
                isShimmering: isShimmering,
            ),
        ]

        self.content = content
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public init(
        _ badges: [DBadgeItem],
        @ViewBuilder content: @escaping () -> Content,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
    ) {
        self.badges = badges

        self.content = content
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            content()
                .overlay(
                    alignment: .topTrailing,
                ) {
                    if !visibleBadges.isEmpty {
                        HStack(
                            spacing: size.s4,
                        ) {
                            ForEach(
                                visibleBadges.indices,
                                id: \.self,
                            ) { index in
                                let badge = visibleBadges[
                                    index,
                                ]

                                DBadgeItemView(
                                    badge: badge,
                                )
                                .if(
                                    badge.isShimmering,
                                ) {
                                    $0.dShimmer()
                                }
                            }
                        }
                        .offset(
                            x: size.s10,
                            y: -size.s10,
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

    private var visibleBadges: [DBadgeItem] {
        badges.filter(
            \.isVisible,
        )
    }
}

#Preview {
    DScreen { _, _ in
        VStack(
            spacing: 32,
        ) {
            DBadge(
                "New",
            ) {
                DCard(
                    action: {},
                ) {
                    HStack {
                        DText(
                            "Card with badge",
                        )
                        .dStyle()

                        Spacer()
                    }
                }
            }

            DBadge(
                "Pro",
                isShimmering: true,
            ) {
                DCard(
                    action: {},
                ) {
                    HStack {
                        DText(
                            "Shimmering pro badge",
                        )
                        .dStyle()

                        Spacer()
                    }
                }
            }

            DBadge(
                "Long badge title",
            ) {
                DText(
                    "Badge grows to the left",
                )
                .dStyle()
            }

            DBadge(
                [
                    DBadgeItem(
                        "Pro",
                        isShimmering: true,
                    ),
                    DBadgeItem(
                        "Coming soon",
                    ),
                ],
            ) {
                DText(
                    "Card with multiple badges",
                )
                .dStyle()
            }
        }
        .padding()
    }
    .dThemeWrapper()
}
