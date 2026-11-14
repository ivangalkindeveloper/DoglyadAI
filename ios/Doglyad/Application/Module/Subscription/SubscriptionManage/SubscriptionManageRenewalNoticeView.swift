import DoglyadUI
import SwiftUI

struct SubscriptionManageRenewalNoticeView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let status: SubscriptionStatus?

    init(
        status: SubscriptionStatus?,
    ) {
        self.status = status
    }

    var body: some View {
        switch status?.source {
        case .robokassa:
            if status?.isAutoRenewing == false {
                DText(
                    l10n[
                        .subscriptionManageRenewalAuthorizationDescription,
                    ],
                )
                .dStyle(
                    font: typography.textXSmall,
                    color: color.grayscalePlacehold,
                )
                .padding(
                    .horizontal,
                    size.s8,
                )
                .padding(
                    .bottom,
                    size.s8,
                )
            }
        case .apple, .none: EmptyView()
        }
    }
}
