import SwiftUI

public struct DBadge<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme

    let badges: [DBadgeItem]
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    let content: () -> Content

    public init(
        _ title: LocalizedStringResource,
        isVisible: Bool = true,
        isShimmering: Bool = false,
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        badges = [
            DBadgeItem(
                title,
                isVisible: isVisible,
                isShimmering: isShimmering,
            ),
        ]
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.content = content
    }

    public init(
        _ badges: [DBadgeItem],
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.badges = badges
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.content = content
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
                DButtonCard(
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
                DButtonCard(
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
