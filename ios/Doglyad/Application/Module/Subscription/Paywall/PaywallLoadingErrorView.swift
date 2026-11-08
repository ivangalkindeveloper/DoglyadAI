import DoglyadUI
import SwiftUI

struct PaywallLoadingErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel
    let state: PaywallLoadingFailedState

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
            ErrorBodyView(
                description: state.errorDescription,
            )

            DButton(
                title: l10n[
                    .paywallRetryButton,
                ],
                action: viewModel.onTapRetry,
            )
            .dStyle(
                .primaryChip,
            )
        }
    }
}
