import DoglyadUI
import SwiftUI

struct PaidBadgeModifier: ViewModifier {
    @EnvironmentObject private var l10n: L10N

    let availability: SubscriptionFeatureAvailability

    @ViewBuilder
    func body(
        content: Content,
    ) -> some View {
        switch availability {
        case .unavailable:
            EmptyView()
        case .offered:
            DBadge(
                l10n[
                    .subscriptionProLabel,
                ],
                isShimmering: true,
            ) {
                content
            }
        case .available:
            content
        }
    }
}
