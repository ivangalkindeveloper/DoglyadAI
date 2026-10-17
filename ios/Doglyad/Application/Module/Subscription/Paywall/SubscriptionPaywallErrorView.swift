import DoglyadUI
import SwiftUI

struct SubscriptionPaywallErrorView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: SubscriptionPaywallViewModel
    var body: some View {
        switch viewModel.state {
        case let state as SubscriptionPaywallFailedState:
            DText(
                state.errorDescription,
            ).dStyle(
                font: typography.textSmall,
                color: color.dangerDefault,
            )
            DButton(
                title: l10n[
                    .subscriptionPaywallRetryButton,
                ],
                action: viewModel.onTapRetry,
            ).dStyle(
                .textWeak,
            )
        default: EmptyView()
        }
    }
}
