import DoglyadUI
import SwiftUI

struct PaywallFailedContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallOperationErrorState

    init(
        state: PaywallOperationErrorState,
    ) {
        self.state = state
    }

    var body: some View {
        PaywallOffersView(
            state: state,
        )
    }
}
