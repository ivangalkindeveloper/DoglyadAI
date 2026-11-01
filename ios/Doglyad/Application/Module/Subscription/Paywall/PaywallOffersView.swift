import DoglyadUI
import SwiftUI

struct PaywallOffersView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallContentState

    var body: some View {
        PaywallSegmentTypeView(
            state: state,
        )

        PaywallFeaturesView(
            state: state,
        )

        PaywallPlansView(
            state: state,
        )
    }
}
