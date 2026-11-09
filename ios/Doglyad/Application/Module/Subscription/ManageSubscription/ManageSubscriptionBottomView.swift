import DoglyadUI
import SwiftUI

struct ManageSubscriptionBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel

    var body: some View {
        switch viewModel.state {
        case _ as ManageSubscriptionErrorState:
            DButton(
                title: l10n[
                    .buttonRetry,
                ],
                action: viewModel.onTapRetry,
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                size.s16,
            )
        default: EmptyView()
        }
    }
}
