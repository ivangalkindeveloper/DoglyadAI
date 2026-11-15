import DoglyadUI
import SwiftUI

struct SubscriptionPaywallContinueView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionPaywallViewModel
    let state: any SubscriptionPaywallStateProtocol

    init(
        state: any SubscriptionPaywallStateProtocol,
    ) {
        self.state = state
    }

    var body: some View {
        switch state {
        case _ as SubscriptionPaywallCatalogLoadingState:
            EmptyView()
        case _ as SubscriptionPaywallCatalogErrorState:
            DButton(
                title: l10n[
                    .subscriptionPaywallRetryButton,
                ],
                action: viewModel.onTapRetry,
                accessibilityIdentifier: "paywall.retry",
            )
            .dStyle(
                .primaryButton,
            )
        case let restoring as SubscriptionPaywallRestoreLoadingState:
            SubscriptionPaywallContinueView(
                state: restoring.previousState,
            )
        case let failed as SubscriptionPaywallOperationErrorState:
            SubscriptionPaywallContinueView(
                state: failed.previousState,
            )
        case _ as SubscriptionPaywallContentState:
            DButton(
                title: l10n[
                    .subscriptionPaywallContinueButton,
                ],
                action: viewModel.onTapContinue,
                isLoading: viewModel.isProcessing,
                isDisabled: !viewModel.isProcessing && !viewModel.isContinueEnabled,
                accessibilityIdentifier: "paywall.continue",
            )
            .dStyle(
                .primaryButton,
            )
        default: EmptyView()
        }
    }
}
