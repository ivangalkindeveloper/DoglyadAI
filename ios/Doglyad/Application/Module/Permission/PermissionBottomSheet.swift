import SwiftUI

struct PermissionBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel

    let arguments: PermissionArguments

    var body: some View {
        PermissionBottomSheetView(
            viewModel: PermissionViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getSettingsAI: { [subscriptionViewModel] in subscriptionViewModel.resolveSettingsAI() },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                arguments: arguments,
            ),
        )
    }
}
