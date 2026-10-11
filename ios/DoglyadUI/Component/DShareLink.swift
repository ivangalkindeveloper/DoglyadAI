import SwiftUI

public struct DShareLink<Content: View>: DView {
    @EnvironmentObject public var theme: DTheme
    private let item: String
    private let content: Content

    public init(
        item: String,
        @ViewBuilder content: () -> Content,
    ) {
        self.item = item
        self.content = content()
    }

    public var body: some View {
        ShareLink(
            item: item,
        ) { content }
            .buttonStyle(
                DButtonStyle(
                    .card,
                ),
            )
    }
}
