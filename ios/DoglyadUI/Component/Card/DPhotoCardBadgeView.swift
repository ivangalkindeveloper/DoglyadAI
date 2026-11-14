import SwiftUI

struct DPhotoCardBadgeView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let badge: DPhotoCardConfiguration.Badge
    var isDisabled: Bool = false

    init(
        badge: DPhotoCardConfiguration.Badge,
        isDisabled: Bool = false,
    ) {
        self.badge = badge
        self.isDisabled = isDisabled
    }

    var body: some View {
        switch badge {
        case let .delete(
            action,
        ):
            DCloseButton(
                style: .destructive,
                action: action,
                isDisabled: isDisabled,
            )
        case .warning:
            DIconBadge(
                .alert,
                iconColor: color.warningDefaultStrong,
                backgroundColor: color.warningDefault,
            )
            .allowsHitTesting(
                false,
            )
        }
    }
}
