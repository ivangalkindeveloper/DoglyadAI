import DoglyadUI
import Router
import SwiftUI

struct ImportMediaBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: ImportMediaArguments

    var body: some View {
        ImportMediaBottomSheetView(
            viewModel: ImportMediaViewModel(
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
                getSettingsAI: { [subscriptionViewModel] in subscriptionViewModel.resolveSettingsAI() },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
            ),
        )
    }
}

#Preview {
    ImportMediaBottomSheet(
        arguments: ImportMediaArguments(
            onTapCamera: {},
            onTapGallery: {},
        ),
    )
    .previewable()
}
