import DoglyadUI
import Router
import SwiftUI

struct SubscriptionRecoveryScreen: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionRecoveryArguments?

    init(
        arguments: SubscriptionRecoveryArguments?,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        SubscriptionRecoveryScreenView(
            viewModel: SubscriptionRecoveryViewModel(
                messager: messager,
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
                recover: { [subscriptionViewModel] in
                    try await subscriptionViewModel.recover(
                        key: $0,
                    )
                },
            ),
        )
    }
}
