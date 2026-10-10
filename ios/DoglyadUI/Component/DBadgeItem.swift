import SwiftUI

public struct DBadgeItem {
    let title: LocalizedStringResource
    let isVisible: Bool
    let isShimmering: Bool

    public init(
        _ title: LocalizedStringResource,
        isVisible: Bool = true,
        isShimmering: Bool = false,
    ) {
        self.title = title
        self.isVisible = isVisible
        self.isShimmering = isShimmering
    }
}
