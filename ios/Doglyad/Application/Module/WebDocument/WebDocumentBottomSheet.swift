import Router
import SwiftUI

struct WebDocumentBottomSheet: View {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel

    let arguments: WebDocumentArguments

    var body: some View {
        WebDocumentBottomSheetView(
            viewModel: WebDocumentViewModel(
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
    let l10n = DependencyContainer.previewable.l10n
    WebDocumentBottomSheet(
        arguments: WebDocumentArguments(
            url: URL(
                string: "https://ivangalkindeveloper.github.io/DoglyadAI/legal/privacy-policy/",
            )!,
            title: l10n[
                .privacyPolicyTitle,
            ],
        ),
    )
    .previewable()
}
