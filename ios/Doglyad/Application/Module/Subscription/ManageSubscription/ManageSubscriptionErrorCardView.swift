import DoglyadUI
import SwiftUI

struct ManageSubscriptionErrorCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionFailedState

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s12,
        ) {
            DText(
                state.errorDescription,
            ).dStyle(
                font: typography.textSmall,
                color: color.dangerDefault,
            )

            DButton(
                title: l10n[
                    .buttonRetry,
                ],
                action: viewModel.onTapRetry,
            ).dStyle(
                .primaryButton,
            )
        }.padding(
            size.s16,
        ).background(
            DCardBackground(
                cornerRadius: size.s16,
                color: color.grayscaleBackground,
            ),
        )
    }
}
