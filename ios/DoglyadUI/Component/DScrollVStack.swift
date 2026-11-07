import SwiftUI

public struct DScrollVStack<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let alignment: HorizontalAlignment
    private let spacing: CGFloat?
    private let padding: EdgeInsets
    private let accessibilityElement: AccessibilityChildBehavior?
    private let accessibilityIdentifier: String?

    private let content: Content

    public init(
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = nil,
        padding: EdgeInsets = EdgeInsets(),
        accessibilityElement: AccessibilityChildBehavior? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content,
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.padding = padding
        self.accessibilityElement = accessibilityElement
        self.accessibilityIdentifier = accessibilityIdentifier

        self.content = content()
    }

    public var body: some View {
        Group {
            ScrollView(
                showsIndicators: false,
            ) {
                VStack(
                    alignment: alignment,
                    spacing: spacing ?? size.s16,
                ) {
                    content
                }.padding(
                    padding,
                )
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
    DScrollVStack(
        padding: EdgeInsets(
            top: 16,
            leading: 16,
            bottom: 32,
            trailing: 16,
        ),
    ) {
        ForEach(
            0 ..< 12,
        ) { _ in
            DListButtonCard(
                title: "Subscription",
                description: "Manage your plan",
                action: {},
            )
        }
    }.dThemeWrapper()
}
