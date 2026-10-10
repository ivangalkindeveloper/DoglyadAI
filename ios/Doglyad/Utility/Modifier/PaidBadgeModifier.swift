import DoglyadUI
import SwiftUI

struct PaidBadgeModifier: ViewModifier {
    @EnvironmentObject private var subscription: SubscriptionViewModel

    let feature: PaidFeature

    @ViewBuilder
    func body(
        content: Content,
    ) -> some View {
        switch subscription.availability(
            of: feature,
        ) {
        case .unavailable:
            EmptyView()
        case .offered:
            DBadge(
                .entitlementPro,
                isShimmering: true,
            ) {
                content
            }
        case .available:
            content
        }
    }
}

extension View {
    func paidBadge(
        _ feature: PaidFeature,
    ) -> some View {
        modifier(
            PaidBadgeModifier(
                feature: feature,
            ),
        )
    }
}
