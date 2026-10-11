import Router
import SwiftUI

struct SelectNeuralModelBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SelectNeuralModelArguments?

    var body: some View {
        SelectNeuralModelBottomSheetView(
            viewModel: SelectNeuralModelViewModel(
                container: container,
                router: router,
                arguments: arguments,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.neuralModelSettings },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
            ),
        )
    }
}

#Preview {
    SelectNeuralModelBottomSheet(
        arguments: nil,
    )
    .previewable()
}
