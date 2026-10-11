import Router
import SwiftUI

struct SelectUSExaminationTypeBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel

    let arguments: SelectUSExaminationTypeArguments?

    var body: some View {
        SelectUSExaminationTypeBottomSheetView(
            viewModel: SelectUSExaminationTypeViewModel(
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
            ),
        )
    }
}

#Preview {
    SelectUSExaminationTypeBottomSheet(
        arguments: nil,
    )
    .previewable()
}
