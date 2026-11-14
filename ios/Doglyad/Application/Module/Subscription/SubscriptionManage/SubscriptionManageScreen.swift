import DoglyadUI
import Router
import SwiftUI

struct SubscriptionManageScreen: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionManageArguments?

    init(
        arguments: SubscriptionManageArguments?,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        SubscriptionManageScreenView(
            viewModel: SubscriptionManageViewModel(
                messager: messager,
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.status
                },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in
                    subscriptionViewModel.observeStatus(
                        observer,
                    )
                },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in
                    subscriptionViewModel.update(
                        status: status,
                    )
                },
                getSettingsAI: { [subscriptionViewModel] in
                    subscriptionViewModel.resolveSettingsAI()
                },
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                },
                arguments: arguments,
                manageSubscription: { [subscriptionViewModel] in
                    try await subscriptionViewModel.manageSubscription()
                },
                restorePurchases: { [subscriptionViewModel] in
                    try await subscriptionViewModel.restorePurchases()
                },
                requestRefund: { [subscriptionViewModel] in
                    try await subscriptionViewModel.requestRefund()
                },

            ),
        )
    }
}
