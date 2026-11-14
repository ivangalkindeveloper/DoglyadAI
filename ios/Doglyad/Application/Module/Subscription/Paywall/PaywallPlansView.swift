import DoglyadUI
import SwiftUI

struct PaywallPlansView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallContentState

    init(
        state: PaywallContentState,
    ) {
        self.state = state
    }

    var body: some View {
        VStack(
            spacing: size.s8,
        ) {
            ForEach(
                state.displayedPlans,
            ) { plan in
                PaywallPlanCardView(
                    state: state,
                    plan: plan,
                )
            }
        }
        .padding(
            .bottom,
            size.s8,
        )
    }
}
