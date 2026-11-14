import DoglyadUI
import SwiftUI

struct PaywallStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: any PaywallStateProtocol

    init(
        state: any PaywallStateProtocol,
    ) {
        self.state = state
    }

    var body: some View {
        switch state {
        case _ as PaywallCatalogLoadingState:
            PaywallLoadingView()
        case let restoring as PaywallRestoreLoadingState:
            PaywallStateView(
                state: restoring.previousState,
            )
        case let failed as PaywallCatalogErrorState:
            PaywallLoadingErrorView(
                state: failed,
            )
        case let failed as PaywallOperationErrorState:
            PaywallFailedContentView(
                state: failed,
            )
        case let content as PaywallContentState:
            PaywallOffersView(
                state: content,
            )
        default: EmptyView()
        }
    }
}
