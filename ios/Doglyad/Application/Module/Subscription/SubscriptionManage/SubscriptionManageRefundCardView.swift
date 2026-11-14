import DoglyadUI
import SwiftUI

struct SubscriptionManageRefundCardView: DViewProtocol {
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
        case _ as SubscriptionManageActiveState:
            DListButtonCard(
                title: l10n[
                    .subscriptionManageRefundButton,
                ],
                description: viewModel.refundDescription,
                action: viewModel.onTapRefund,
                isDisabled: viewModel.isProcessing,
            )
        default: EmptyView()
        }
    }
}
