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

    init(
        arguments: TemplateAddArguments?,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        TemplateAddScreenView(
            viewModel: TemplateAddViewModel(
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
                messager: messager,
                onSaveTemplate: { [ultrasoundViewModel, arguments] template in
                    try await ultrasoundViewModel.saveTemplate(
                        template,
                    )
                    arguments?.onTemplatesChanged?()
                    try await arguments?.onAddSuccess?(
                        template,
                    )
                },
            ),
        )
    }
}
