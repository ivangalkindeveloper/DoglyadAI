import DoglyadUI
import Router
import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    let arguments: HistoryArguments?

    var body: some View {
        HistoryScreenView(
            viewModel: HistoryViewModel(
                messager: messager,
                container: container,
                router: router,
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
            ),
        )
    }
}
