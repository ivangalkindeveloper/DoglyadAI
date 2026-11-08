import DoglyadUI
import SwiftUI

struct ManageSubscriptionActionsView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionSuccessState

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            DListButtonCard(
                title: l10n[
                    .manageSubscriptionChangeTypeButton,
                ],
                description: l10n[
                    .manageSubscriptionChangeTypeDescription,
                ],
                action: viewModel.onTapChangeType,
            )

            DListButtonCard(
                title: l10n[
                    .manageSubscriptionRestoreButton,
                ],
                description: l10n[
                    .manageSubscriptionRestoreDescription,
                ],
                action: viewModel.onTapRestore,
            )

            if viewModel.isManageAvailable {
                DListButtonCard(
                    title: viewModel.manageTitle,
                    description: viewModel.manageDescription,
                    action: viewModel.onTapManageSubscription,
                )
            }

            ManageSubscriptionRenewalNoticeView(
                status: (state as? ManageSubscriptionActiveState)?.status,
            )
        }.disabled(
            viewModel.isProcessing,
        )
    }
}
