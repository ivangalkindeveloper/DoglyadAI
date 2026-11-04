import DoglyadUI
import Router
import SwiftUI

struct ReportReceivedBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: ReportReceivedArguments

    var body: some View {
        ReportReceivedBottomSheetView(
            viewModel: ReportReceivedViewModel(
                container: container,
                messager: messager,
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
                getUserEmail: { [ultrasoundViewModel] in
                    ultrasoundViewModel.userEmail
                },
                currentReport: { [ultrasoundViewModel] in
                    ultrasoundViewModel.reportGenerations.current(
                        $0,
                    )
                },
                observeReports: { [ultrasoundViewModel] in
                    ultrasoundViewModel.reportGenerations.observe(
                        $0,
                    )
                },
                retryGeneration: { [ultrasoundViewModel] in
                    try await ultrasoundViewModel.reportGenerations.retry(
                        $0,
                    )
                },
            ),
        )
    }
}
