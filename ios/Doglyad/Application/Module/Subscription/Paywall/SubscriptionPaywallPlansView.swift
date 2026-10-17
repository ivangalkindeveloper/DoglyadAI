import DoglyadUI
import SwiftUI

struct SubscriptionPaywallPlansView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: SubscriptionPaywallViewModel
    var body: some View {
        let displayedState: any SubscriptionPaywallStateProtocol = switch viewModel.state {
        case let state as SubscriptionPaywallRestoringState: state.previousState
        default: viewModel.state
        }
        let isProcessing = switch viewModel.state {
        case _ as SubscriptionPaywallRestoringState, _ as SubscriptionPaywallPurchasingState, _ as SubscriptionPaywallLoadingState: true
        default: false
        }
        switch displayedState {
        case _ as SubscriptionPaywallLoadingState:
            DShimmerPlaceholder().frame(
                height: size.s64,
            )
            DShimmerPlaceholder().frame(
                height: size.s64,
            )
        case _ as SubscriptionPaywallContentState, _ as SubscriptionPaywallPurchasingState, _ as SubscriptionPaywallFailedState:
            ForEach(
                viewModel.plans,
            ) { plan in
                DListButtonCard(
                    title: viewModel.planTitle(
                        plan,
                    ),
                    description: viewModel.planPrice(
                        plan,
                    ),
                    action: { viewModel.onTapPlan(
                        plan,
                    ) },
                )
                .disabled(
                    isProcessing,
                )
            }
        default: DUnexpectedStateView(
                state: displayedState,
            )
        }
    }
}
