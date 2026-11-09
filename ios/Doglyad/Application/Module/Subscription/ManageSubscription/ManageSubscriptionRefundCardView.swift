import DoglyadUI
import SwiftUI

struct ManageSubscriptionRefundCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionSuccessState

    var body: some View {
        switch state {
        case _ as ManageSubscriptionActiveState:
            DListButtonCard(
                title: l10n[
                    .manageSubscriptionRefundButton,
                ],
                description: viewModel.refundDescription,
                action: viewModel.onTapRefund,
                isDisabled: viewModel.isProcessing,
            )
        default: EmptyView()
        }
    }
}
