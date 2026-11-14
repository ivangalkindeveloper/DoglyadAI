import SwiftUI

struct DScreenToolbarHeightPreferenceKey: PreferenceKey {
    init() {}

    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat,
    ) {
        value = nextValue()
    }
}
