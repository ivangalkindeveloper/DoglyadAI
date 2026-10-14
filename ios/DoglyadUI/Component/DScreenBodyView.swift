import SwiftUI

struct DScreenBodyView<Content: View>: View {
    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat
    let onTap: (() -> Void)?
    let content: (CGFloat, CGFloat) -> Content

    var body: some View {
        content(
            toolbarHeight,
            bottomHeight,
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
        )
        .onTapGesture { onTap?() }
    }
}
