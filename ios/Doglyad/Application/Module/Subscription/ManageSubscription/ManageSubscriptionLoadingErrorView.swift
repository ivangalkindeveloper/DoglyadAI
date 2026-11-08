import DoglyadUI
import SwiftUI

struct ManageSubscriptionLoadingErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionFailedState

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
            ErrorBodyView(
                description: state.errorDescription,
            )

            DButton(
                title: l10n[
                    .buttonRetry,
                ],
                action: viewModel.onTapRetry,
            )
            .dStyle(
                .primaryChip,
            )
        }
    }
}
