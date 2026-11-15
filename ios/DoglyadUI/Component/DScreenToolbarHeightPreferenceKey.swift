import SwiftUI

struct DScreenToolbarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    init() {}

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat,
    ) {
        value = nextValue()
    }
}
