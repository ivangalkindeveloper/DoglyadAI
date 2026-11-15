import DoglyadUI
import SwiftUI

struct SubscriptionPaywallPlansView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: SubscriptionPaywallContentState

    init(
        state: SubscriptionPaywallContentState,
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
                SubscriptionPaywallPlanCardView(
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
