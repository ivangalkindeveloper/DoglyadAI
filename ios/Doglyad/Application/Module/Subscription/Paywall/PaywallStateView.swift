import DoglyadUI
import SwiftUI

struct PaywallStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: any PaywallStateProtocol

    var body: some View {
        switch state {
        case let loading as PaywallCatalogLoadingState:
            if let previous = loading.previousState {
                PaywallOffersView(
                    state: previous,
                )
            } else {
                PaywallLoadingView()
            }
        case let restoring as PaywallVerificationLoadingState:
            PaywallStateView(
                state: restoring.previousState,
            )
        case let failed as PaywallLoadingFailedState:
            PaywallLoadingErrorView(
                state: failed,
            )
        case let failed as PaywallOperationFailedState:
            PaywallFailedContentView(
                state: failed,
            )

            PaywallErrorView(
                errorDescription: failed.errorDescription,
            )
        case let pending as PaywallPendingState:
            PaywallPendingView(
                state: pending,
            )
        case let content as PaywallContentState:
            PaywallOffersView(
                state: content,
            )
        default: EmptyView()
        }
    }
}
