import DoglyadUI
import SwiftUI

struct ManageSubscriptionContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionSuccessState

    var body: some View {
        switch state {
        case let active as ManageSubscriptionActiveState:
            ManageSubscriptionSummaryCardView(
                state: active,
            )
        case let inactive as ManageSubscriptionInactiveState:
            ManageSubscriptionEmptyCardView(
                state: inactive,
            )
        default: EmptyView()
        }

        ManageSubscriptionActionsView(
            state: state,
        )

        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DListButtonCard(
                title: l10n[
                    .manageSubscriptionRecoveryButton,
                ],
                description: l10n[
                    .manageSubscriptionRecoveryDescription,
                ],
                action: viewModel.onTapRecovery,
            )

            DListButtonCard(
                title: l10n[
                    .manageSubscriptionSupportButton,
                ],
                description: l10n[
                    .manageSubscriptionSupportDescription,
                ],
                action: viewModel.onTapSupport,
            )

            ManageSubscriptionRefundCardView(
                state: state,
            )
        }.disabled(
            viewModel.isProcessing,
        )
    }
}
