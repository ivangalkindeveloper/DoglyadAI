import DoglyadUI
import SwiftUI

struct PaywallContinueView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel

    let state: any PaywallStateProtocol

    var body: some View {
        switch state {
        case let restoring as PaywallVerificationLoadingState:
            PaywallContinueView(
                state: restoring.previousState,
            )
        case let failed as PaywallOperationFailedState:
            PaywallContinueView(
                state: failed.previousState,
            )
        case _ as PaywallPendingState:
            DButton(
                title: l10n[
                    .subscriptionPaymentRefreshButton,
                ],
                action: viewModel.onTapCheckPayment,
                isLoading: viewModel.isProcessing,
            )
            .dStyle(
                .primaryButton,
            )
        default:
            DButton(
                title: l10n[
                    .paywallContinueButton,
                ],
                accessibilityIdentifier: "paywall.continue",
                action: viewModel.onTapContinue,
                isLoading: viewModel.isProcessing,
                isDisabled: !viewModel.isContinueEnabled,
            )
            .dStyle(
                .primaryButton,
            )
        }
    }
}
