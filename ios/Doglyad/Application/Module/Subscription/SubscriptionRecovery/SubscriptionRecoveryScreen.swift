import Router
import SwiftUI

struct SubscriptionRecoveryScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionRecoveryArguments?

    var body: some View {
        SubscriptionRecoveryScreenView(
            viewModel: SubscriptionRecoveryViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.status
                },
                observeSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.observeStatus(
                        $0,
                    )
                },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] in
                    subscriptionViewModel.update(
                        status: $0,
                    )
                },
                getSettingsAI: { [subscriptionViewModel] in
                    subscriptionViewModel.resolveSettingsAI()
                },
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                },
                arguments: arguments,
                createRecoveryKey: { [subscriptionViewModel] in
                    try await subscriptionViewModel.createRecoveryKey()
                },
                recover: { [subscriptionViewModel] in
                    try await subscriptionViewModel.recover(
                        key: $0,
                    )
                },
            ),
        )
    }
}
