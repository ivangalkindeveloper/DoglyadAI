import DoglyadUI
import Router
import SwiftUI

struct TemplateEditScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: TemplateEditArguments

    var body: some View {
        TemplateEditScreenView(
            viewModel: TemplateEditViewModel(
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
                arguments: arguments,
                onSaveTemplate: { [ultrasoundViewModel, arguments] template in
                    try await ultrasoundViewModel.saveTemplate(
                        template,
                        onChanged: {
                            arguments.onTemplatesChanged?()
                        },
                    )
                },
                onDeleteTemplate: { [ultrasoundViewModel, arguments] id in
                    try await ultrasoundViewModel.deleteTemplate(
                        id: id,
                        onChanged: {
                            arguments.onTemplatesChanged?()
                        },
                    )
                },
            ),
        )
    }
}

#Preview {
    TemplateEditScreen(
        arguments: TemplateEditArguments(
            templateId: UUID(),
        ),
    )
    .previewable()
}
