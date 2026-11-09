import DoglyadUI
import SwiftUI

struct PaywallFailedContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallOperationErrorState

    var body: some View {
        PaywallOffersView(
            state: state,
        )
    }
}
