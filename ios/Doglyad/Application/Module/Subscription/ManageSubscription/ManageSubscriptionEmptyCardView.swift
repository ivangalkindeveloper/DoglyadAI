import DoglyadUI
import SwiftUI

struct ManageSubscriptionEmptyCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let state: ManageSubscriptionInactiveState

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DText(
                l10n[
                    .manageSubscriptionEmptyTitle,
                ],
            ).dStyle(
                font: typography.displaySmallBold,
            )

            DText(
                state.notice ?? l10n.text(
                    .manageSubscriptionEmptyDescription,
                ),
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
            )
        }.frame(
            maxWidth: .infinity,
            alignment: .leading,
        ).padding(
            size.s16,
        )
        .background(
            DCardBackground(
                cornerRadius: size.s24,
                color: color.grayscaleBackground,
            ),
        )
    }
}
