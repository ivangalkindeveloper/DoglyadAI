import Router
import SwiftUI

struct PaywallScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: PaywallArguments?

    var body: some View {
        PaywallScreenView(
            viewModel: PaywallViewModel(
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

#if DEBUG
    #Preview(
        "Русский",
    ) {
        let container = PaywallPreviewFactory.makeContainer()
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .paywall,
            ),
        )

        PaywallScreenView(
            viewModel: PaywallPreviewFactory.makeViewModel(
                container: container,
                router: router,
            ),
        )
        .previewable(
            container: container,
            router: router,
        )
    }

    #Preview(
        "English",
    ) {
        let container = PaywallPreviewFactory.makeContainer(
            code: "en",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .paywall,
            ),
        )

        PaywallScreenView(
            viewModel: PaywallPreviewFactory.makeViewModel(
                container: container,
                router: router,
            ),
        )
        .previewable(
            container: container,
            router: router,
        )
    }
#endif
