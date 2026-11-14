import DoglyadUI
import SwiftUI

struct SubscriptionManageContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionManageViewModel
    let state: SubscriptionManageSuccessState

    init(
        state: SubscriptionManageSuccessState,
    ) {
        self.state = state
    }

    var body: some View {
        switch state {
        case let active as SubscriptionManageActiveState:
            SubscriptionManageSummaryCardView(
                state: active,
            )

            SubscriptionManageRenewalNoticeView(
                status: active.status,
            )
        case let inactive as SubscriptionManageInactiveState:
            SubscriptionManageEmptyCardView(
                state: inactive,
            )
        default: EmptyView()
        }

        SubscriptionManageActionsView(
            state: state,
        )

        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DListButtonCard(
                title: l10n[
                    .subscriptionManageCopyRecoveryKeyButton,
                ],
                description: l10n[
                    .subscriptionManageRecoveryDescription,
                ],
                action: viewModel.onTapCopyRecoveryKey,
                isDisabled:
                viewModel.isProcessing,
            )

            DListButtonCard(
                title: l10n[
                    .subscriptionManageSupportButton,
                ],
                description: l10n[
                    .subscriptionManageSupportDescription,
                ],
                action: viewModel.onTapSupport,
                isDisabled:
                viewModel.isProcessing,
            )

            SubscriptionManageRefundCardView(
                state: state,
            )
        }
    }
}
