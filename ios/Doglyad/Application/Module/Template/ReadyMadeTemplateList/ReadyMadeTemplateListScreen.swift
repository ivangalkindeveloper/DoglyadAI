import Router
import SwiftUI

struct ReadyMadeTemplateListScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel

    let arguments: ReadyMadeTemplateListArguments

    var body: some View {
        ReadyMadeTemplateListScreenView(
            viewModel: ReadyMadeTemplateListViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.resolveNeuralModelSettings() },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                arguments: arguments,
            ),
        )
    }
}

#Preview {
    ReadyMadeTemplateListScreen(
        arguments: ReadyMadeTemplateListArguments(
            onTemplateSelected: { _ in },
        ),
    )
    .previewable()
}
