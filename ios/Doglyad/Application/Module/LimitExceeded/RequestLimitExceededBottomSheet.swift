import Router
import SwiftUI

struct RequestLimitExceededBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: RequestLimitExceededArguments?

    var body: some View {
        RequestLimitExceededBottomSheetView(
            viewModel: RequestLimitExceededViewModel(
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
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in await subscriptionViewModel.refreshStatus() },
            ),
        )
    }
}

#Preview {
    RequestLimitExceededBottomSheet(
        arguments: nil,
    )
    .previewable()
}
