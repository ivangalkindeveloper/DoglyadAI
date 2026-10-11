import DoglyadUI
import Router
import SwiftUI

struct TemplateAddScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: TemplateAddArguments?

    var body: some View {
        TemplateAddScreenView(
            viewModel: TemplateAddViewModel(
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
                messager: messager,
                onSaveTemplate: { [ultrasoundViewModel, arguments] template in
                    ultrasoundViewModel.saveTemplate(
                        template,
                        onChanged: {
                            arguments?.onTemplatesChanged?()
                            arguments?.onAddSuccess?(
                                template,
                            )
                        },
                    )
                },
            ),
        )
    }
}

#Preview {
    TemplateAddScreen(
        arguments: nil,
    )
    .previewable()
}
