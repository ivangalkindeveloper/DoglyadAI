import DoglyadUI
import SwiftUI

struct SubscriptionManageEmptyCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let state: SubscriptionManageInactiveState

    init(
        state: SubscriptionManageInactiveState,
    ) {
        self.state = state
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DText(
                l10n[
                    .subscriptionManageEmptyTitle,
                ],
            ).dStyle(
                font: typography.displaySmallBold,
            )

            DText(
                state.notice ?? l10n.text(
                    .subscriptionManageEmptyDescription,
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
