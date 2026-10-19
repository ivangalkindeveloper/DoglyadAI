import Router
import SwiftUI

struct StorageClearAllBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel

    let arguments: StorageClearAllArguments?

    var body: some View {
        StorageClearAllBottomSheetView(
            viewModel: StorageClearAllViewModel(
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

#Preview {
    StorageClearAllBottomSheet(
        arguments: nil,
    )
    .previewable()
}
