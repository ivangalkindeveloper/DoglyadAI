import DoglyadUI
import Router
import SwiftUI

struct SubscriptionChangeBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionChangeArguments

    init(
        arguments: SubscriptionChangeArguments,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        SubscriptionChangeBottomSheetView(
            viewModel: SubscriptionChangeViewModel(
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
            ),
        )
    }
}
