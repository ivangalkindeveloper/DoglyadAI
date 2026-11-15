import DoglyadUI
import SwiftUI

struct SubscriptionPaywallFailedContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: SubscriptionPaywallOperationErrorState

    init(
        state: SubscriptionPaywallOperationErrorState,
    ) {
        self.state = state
    }

    var body: some View {
        SubscriptionPaywallOffersView(
            state: state,
        )
    }
}
