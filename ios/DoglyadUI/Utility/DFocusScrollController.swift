import SwiftUI

@MainActor
enum DFocusScrollController {
    static func scroll(
        to focus: some Hashable,
        proxy: ScrollViewProxy,
        anchor: UnitPoint,
        animation: Animation?,
    ) {
        withAnimation(
            animation,
        ) {
            proxy.scrollTo(
                focus,
                anchor: anchor,
            )
        }
    }
}
