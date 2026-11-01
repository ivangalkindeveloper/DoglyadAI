import DoglyadUI
import SwiftUI

struct ManageSubscriptionRenewalNoticeView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let status: SubscriptionStatus?

    var body: some View {
        switch status?.source {
        case .yookassa:
            if status?.isAutoRenewing == false {
                DText(
                    l10n[
                        .manageSubscriptionRenewalStoppedDescription,
                    ],
                )
                .dStyle(
                    font: typography.textXSmall,
                    color: color.grayscalePlacehold,
                )
                .padding(
                    .horizontal,
                    size.s12,
                ).padding(
                    .top,
                    size.s4,
                )
            }
        case .apple, .none: EmptyView()
        }
    }
}
