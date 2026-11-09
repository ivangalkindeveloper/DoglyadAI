import DoglyadUI
import SwiftUI

struct ManageSubscriptionErrorCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionErrorState

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

        }.padding(
            size.s16,
        ).background(
            DCardBackground(
                cornerRadius: size.cardCornerRadius,
                color: color.grayscaleBackground,
            ),
        )
    }
}
