import DoglyadUI
import SwiftUI

struct SubscriptionPaywallOffersView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: SubscriptionPaywallContentState

    init(
        state: SubscriptionPaywallContentState,
    ) {
        self.state = state
    }

    var body: some View {
        SubscriptionPaywallSegmentTypeView(
            state: state,
        )

        SubscriptionPaywallFeaturesView(
            state: state,
        )

        SubscriptionPaywallPlansView(
            state: state,
        )

        SubscriptionPaywallAutoRenewalView(
            state: state,
        )

        SubscriptionPaywallFooterLinksView()
    }
}
