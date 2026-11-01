import SwiftUI

public struct DScrollVStack<Content: View>: DViewProtocol {
    @EnvironmentObject public var theme: DTheme
    private let alignment: HorizontalAlignment
    private let spacing: CGFloat?
    private let padding: EdgeInsets
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = nil,
        padding: EdgeInsets = EdgeInsets(),
        @ViewBuilder content: () -> Content,
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
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
