import DoglyadUI
import SwiftUI

struct SubscriptionManageActionsView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionManageViewModel
    let state: SubscriptionManageSuccessState

    init(
        state: SubscriptionManageSuccessState,
    ) {
        self.state = state
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DListButtonCard(
                title: l10n[
                    .subscriptionManageChangeTypeButton,
                ],
                description: l10n[
                    .subscriptionManageChangeTypeDescription,
                ],
                action: viewModel.onTapChangeType,
                isDisabled:
                !viewModel.isChangePlanAvailable,
            )

            DListButtonCard(
                title: l10n[
                    .subscriptionManageRestoreButton,
                ],
                description: l10n[
                    .subscriptionManageRestoreDescription,
                ],
                action: viewModel.onTapRestore,
                isDisabled:
                viewModel.isProcessing,
            )

            if viewModel.isManageAvailable {
                DListButtonCard(
                    title: viewModel.manageTitle,
                    description: viewModel.manageDescription,
                    action: viewModel.onTapSubscriptionManage,
                    isDisabled:
                    viewModel.isProcessing,
                )
            }

            SubscriptionManageAutoRenewalView(
                status: (state as? SubscriptionManageActiveState)?.status,
            )
        }
    }
}
