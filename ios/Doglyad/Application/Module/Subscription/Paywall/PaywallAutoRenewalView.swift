import DoglyadUI
import SwiftUI

struct PaywallAutoRenewalView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel
    let state: PaywallContentState

    init(
        state: PaywallContentState,
    ) {
        self.state = state
    }

    var body: some View {
        if state.selectedPlan?.source == .robokassa {
            DToggleCard(
                title: l10n[
                    .paywallAutoRenewalLabel,
                ],
                isOn: .constant(
                    state.isAutoRenewing,
                ),
                action: viewModel.onToggleAutoRenewal,
                isDisabled: viewModel.isProcessing,
                accessibilityIdentifier: "paywall.autoRenewal",
            )
        }
    }
}
