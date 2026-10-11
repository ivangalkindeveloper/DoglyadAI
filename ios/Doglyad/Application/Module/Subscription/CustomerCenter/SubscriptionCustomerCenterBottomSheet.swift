import Router
import SwiftUI

struct SubscriptionCustomerCenterBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionCustomerCenterArguments?

    var body: some View {
        SubscriptionCustomerCenterBottomSheetView(
            viewModel: SubscriptionCustomerCenterViewModel(
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
    SubscriptionCustomerCenterBottomSheet(
        arguments: nil,
    )
    .previewable()
}
