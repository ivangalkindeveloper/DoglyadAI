import DoglyadUI
import Router
import SwiftUI

struct SelectTemplateBottomSheet: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SelectTemplateArguments

    var body: some View {
        SelectTemplateBottomSheetView(
            viewModel: SelectTemplateViewModel(
                container: container,
                messager: messager,
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
            ),
        )
    }
}
