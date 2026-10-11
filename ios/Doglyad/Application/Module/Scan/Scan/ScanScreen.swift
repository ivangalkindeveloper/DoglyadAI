import DoglyadUI
import Router
import SwiftUI

struct ScanScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: ScanArguments?

    var body: some View {
        ScanScreenView(
            viewModel: ScanViewModel(
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
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.neuralModelSettings },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                observeExaminationChanges: { [ultrasoundViewModel] observer in ultrasoundViewModel.observeChanges(
                    observer,
                ) },
                getSelectedTemplate: { [ultrasoundViewModel] in
                    ultrasoundViewModel.template
                },
                onTemplateSelected: { [ultrasoundViewModel] template in
                    ultrasoundViewModel.selectTemplate(
                        template,
                    )
                },
                onTemplateReset: { [ultrasoundViewModel] in
                    ultrasoundViewModel.resetTemplate()
                },
                getNeuralModel: { [ultrasoundViewModel] in
                    ultrasoundViewModel.neuralModel
                },
                onNeuralModelSelected: { [ultrasoundViewModel] model in
                    ultrasoundViewModel.saveNeuralModel(
                        model,
                    )
                },
            ),
        )
    }
}

#Preview {
    ScanScreen(
        arguments: nil,
    )
    .previewable()
}
