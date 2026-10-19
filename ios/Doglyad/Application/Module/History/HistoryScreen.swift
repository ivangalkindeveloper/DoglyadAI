import DoglyadUI
import Router
import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: HistoryArguments?

    var body: some View {
        HistoryScreenView(
            viewModel: HistoryViewModel(
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
            ),
        )
    }
}

#Preview {
    HistoryScreen(
        arguments: nil,
    )
    .previewable()
}
