import DoglyadUI
import Router
import SwiftUI

struct PaywallScreen: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: PaywallArguments?

    var body: some View {
        PaywallScreenView(
            viewModel: PaywallViewModel(
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
                purchase: { [subscriptionViewModel] plan in
                    try await subscriptionViewModel.purchase(
                        plan: plan,
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
