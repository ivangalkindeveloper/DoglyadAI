import DoglyadUI
import Router
import SwiftUI

struct SubscriptionAutoRenewalDisablingBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    @EnvironmentObject private var messager: DMessager
    let arguments: SubscriptionAutoRenewalDisablingArguments?

    init(
        arguments: SubscriptionAutoRenewalDisablingArguments?,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        SubscriptionAutoRenewalDisablingBottomSheetView(
            viewModel: SubscriptionAutoRenewalDisablingViewModel(
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
                disableAutoRenewal: { [subscriptionViewModel] in
                    try await subscriptionViewModel.setAutoRenewal(
                        isAutoRenewing: false,
                    )
                },
            ),
        )
    }
}
