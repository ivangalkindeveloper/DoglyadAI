import SwiftUI

struct PhotoCardConfiguration {
    let badge: Badge?

    init(
        badge: Badge? = nil,
    ) {
        self.badge = badge
    }

    var isBadgeVisible: Bool { badge != nil }

    enum Badge {
        case delete(action: () -> Void)
        case warning(accessibilityLabel: LocalizedStringResource)
    }
}
