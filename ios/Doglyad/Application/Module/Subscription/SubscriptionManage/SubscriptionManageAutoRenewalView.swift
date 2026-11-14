import DoglyadUI
import SwiftUI

struct SubscriptionManageAutoRenewalView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionManageViewModel
    let status: SubscriptionStatus?

    init(
        status: SubscriptionStatus?,
    ) {
        self.status = status
    }

    var body: some View {
        if let status, status.source == .robokassa, status.isAutoRenewing {
            DListButtonCard(
                title: l10n[
                    .subscriptionManageDisableAutoRenewalButton,
                ],
                action: viewModel.onTapDisableAutoRenewal,
                isDisabled: viewModel.isProcessing,
                accessibilityIdentifier: "subscriptionManage.disableAutoRenewal",
            )
        }
    }
}
