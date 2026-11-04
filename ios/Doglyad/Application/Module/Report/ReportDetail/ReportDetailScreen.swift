import DoglyadUI
import Router
import SwiftUI

struct ReportDetailScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: ReportDetailArguments

    var body: some View {
        ReportDetailScreenView(
            viewModel: ReportDetailViewModel(
                container: container,
                messager: messager,
                router: router,
                initialReport: arguments.report,
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
                observeExaminationChanges: { [ultrasoundViewModel] observer in
                    ultrasoundViewModel.observeChanges(
                        observer,
                    )
                },
                getSelectedTemplate: { [ultrasoundViewModel] in
                    ultrasoundViewModel.template
                },
                getNeuralModel: { [ultrasoundViewModel] in
                    ultrasoundViewModel.neuralModel
                },
                onNeuralModelSelected: { [ultrasoundViewModel] model in
                    try await ultrasoundViewModel.saveNeuralModel(
                        model,
                    )
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
                onStartReportGeneration: { [ultrasoundViewModel] request, report in
                    try await ultrasoundViewModel.reportGenerations.start(
                        request: request,
                        replacing: report,
                    )
                },
            ),
        )
    }
}
