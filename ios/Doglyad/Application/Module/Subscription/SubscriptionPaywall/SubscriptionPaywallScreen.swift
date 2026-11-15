import DoglyadUI
import Router
import SwiftUI

struct SubscriptionPaywallScreen: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionPaywallArguments?

    init(
        arguments: SubscriptionPaywallArguments?,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        SubscriptionPaywallScreenView(
            viewModel: SubscriptionPaywallViewModel(
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
                purchase: { [subscriptionViewModel] plan, isAutoRenewing in
                    try await subscriptionViewModel.purchase(
                        plan: plan,
                        isAutoRenewing: isAutoRenewing,
                    )
                },
                restorePurchases: { [subscriptionViewModel] in
                    try await subscriptionViewModel.restorePurchases()
                },
                checkPurchase: { [subscriptionViewModel] in
                    try await subscriptionViewModel.checkPurchase()
                },
            ),
        )
    }
}
