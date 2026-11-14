import DoglyadUI
import SwiftUI

struct PaywallContinueView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel
    let state: any PaywallStateProtocol

    init(
        state: any PaywallStateProtocol,
    ) {
        self.state = state
    }

    var body: some View {
        switch state {
        case _ as PaywallCatalogLoadingState:
            EmptyView()
        case _ as PaywallCatalogErrorState:
            DButton(
                title: l10n[
                    .paywallRetryButton,
                ],
                action: viewModel.onTapRetry,
                accessibilityIdentifier: "paywall.retry",
            )
            .dStyle(
                .primaryButton,
            )
        case let restoring as PaywallRestoreLoadingState:
            PaywallContinueView(
                state: restoring.previousState,
            )
        case let failed as PaywallOperationErrorState:
            PaywallContinueView(
                state: failed.previousState,
            )
        case _ as PaywallContentState:
            DButton(
                title: l10n[
                    .paywallContinueButton,
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
