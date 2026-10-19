import DoglyadUI
import Router
import SwiftUI

struct SelectUSExaminationTypeBottomSheet: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel

    let arguments: SelectUSExaminationTypeArguments?

    var body: some View {
        SelectUSExaminationTypeBottomSheetView(
            viewModel: SelectUSExaminationTypeViewModel(
                container: container,
                messager: messager,
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
    SelectUSExaminationTypeBottomSheet(
        arguments: nil,
    )
    .previewable()
}
