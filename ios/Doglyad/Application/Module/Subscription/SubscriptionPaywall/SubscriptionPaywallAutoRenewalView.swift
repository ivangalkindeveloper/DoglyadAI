import DoglyadUI
import SwiftUI

struct SubscriptionPaywallAutoRenewalView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionPaywallViewModel
    let state: SubscriptionPaywallContentState

    init(
        state: SubscriptionPaywallContentState,
    ) {
        self.state = state
    }

    var body: some View {
        switch state.selectedPlan?.source {
        case .robokassa:
            DToggleCard(
                title: l10n[
                    .subscriptionPaywallAutoRenewalLabel,
                ],
                isOn: .constant(
                    state.isAutoRenewing,
                ),
                action: viewModel.onToggleAutoRenewal,
                isDisabled: viewModel.isProcessing,
                accessibilityIdentifier: "paywall.autoRenewal",
            )
        case .apple, .none:
            EmptyView()
        }
    }
}
