import DoglyadUI
import SwiftUI

struct SubscriptionPaywallStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: any SubscriptionPaywallStateProtocol

    init(
        state: any SubscriptionPaywallStateProtocol,
    ) {
        self.state = state
    }

    var body: some View {
        switch state {
        case _ as SubscriptionPaywallCatalogLoadingState:
            SubscriptionPaywallLoadingView()
        case let restoring as SubscriptionPaywallRestoreLoadingState:
            SubscriptionPaywallStateView(
                state: restoring.previousState,
            )
        case let failed as SubscriptionPaywallCatalogErrorState:
            SubscriptionPaywallLoadingErrorView(
                state: failed,
            )
        case let failed as SubscriptionPaywallOperationErrorState:
            SubscriptionPaywallFailedContentView(
                state: failed,
            )
        case let content as SubscriptionPaywallContentState:
            SubscriptionPaywallOffersView(
                state: content,
            )
        default: EmptyView()
        }
    }
}
