import SwiftUI

struct DScreenBodyView<Content: View>: View {
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat
    let onTap: (() -> Void)?
    let content: (CGFloat, CGFloat) -> Content

    init(
        toolbarHeight: CGFloat,
        bottomHeight: CGFloat,
        onTap: (() -> Void)?,
        content: @escaping (CGFloat, CGFloat) -> Content,
    ) {
        self.toolbarHeight = toolbarHeight
        self.bottomHeight = bottomHeight
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        content(
            toolbarHeight,
            bottomHeight,
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
        )
        .onTapGesture {
            onTap?()
        }
    }
}
