import DoglyadUI
import Router
import SwiftUI

struct SelectTranscriptParserBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SelectTranscriptParserArguments

    init(
        arguments: SelectTranscriptParserArguments,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        SelectTranscriptParserBottomSheetView(
            viewModel: SelectTranscriptParserViewModel(
                container: container,
                router: router,
                arguments: arguments,
                getSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.status
                },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in
                    subscriptionViewModel.observeStatus(
                        observer,
                    )
                },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in
                    subscriptionViewModel.update(
                        status: status,
                    )
                },
                getSettingsAI: { [subscriptionViewModel] in
                    subscriptionViewModel.resolveSettingsAI()
                },
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                },
            ),
        )
    }
}
