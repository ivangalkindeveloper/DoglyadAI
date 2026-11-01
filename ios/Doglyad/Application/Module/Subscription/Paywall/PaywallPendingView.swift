import DoglyadUI
import SwiftUI

struct PaywallPendingView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let state: PaywallPendingState

    var body: some View {
        DText(
            state.plan.title,
        ).dStyle(
            font: typography.linkSmall,
        )
        DText(
            l10n[
                .subscriptionPendingDescription,
            ],
        )
        .dStyle(
            font: typography.textSmall,
            color: color.grayscaleLabel,
        )
    }
}
