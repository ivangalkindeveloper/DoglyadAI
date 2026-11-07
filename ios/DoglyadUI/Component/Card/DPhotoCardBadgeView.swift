import SwiftUI

struct DPhotoCardBadgeView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let badge: DPhotoCardConfiguration.Badge

    var body: some View {
        switch badge {
        case let .delete(
            action,
        ):
            DCloseButton(
                style: .destructive,
                action: action,
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
