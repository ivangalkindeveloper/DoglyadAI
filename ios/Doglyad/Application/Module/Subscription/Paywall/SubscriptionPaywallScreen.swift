import Router
import SwiftUI

struct SubscriptionPaywallScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionPaywallArguments?

    var body: some View {
        SubscriptionPaywallScreenView(
            viewModel: SubscriptionPaywallViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.neuralModelSettings },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                arguments: arguments,
                onRefreshStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                },
            ),
        )
    }
}

#Preview {
    SubscriptionPaywallScreen(
        arguments: nil,
    )
    .previewable()
}
