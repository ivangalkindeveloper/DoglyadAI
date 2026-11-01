import DoglyadUI
import SwiftUI

struct PaywallFailedContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallOperationFailedState

    var body: some View {
        switch state.previousState {
        case let pending as PaywallPendingState:
            PaywallPendingView(
                state: pending,
            )
        default:
            PaywallOffersView(
                state: state,
            )
        }
    }
}
