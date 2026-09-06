import DoglyadUI
import Router
import SwiftUI

struct TemplateEditScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: TemplateEditScreenArguments

    var body: some View {
        TemplateEditScreenView(
            viewModel: TemplateEditViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                messager: messager,
                arguments: arguments,
                onSaveTemplate: { [ultrasoundViewModel] template in
                    ultrasoundViewModel.saveTemplate(template)
                },
                onDeleteTemplate: { [ultrasoundViewModel] id in
                    ultrasoundViewModel.deleteTemplate(id: id)
                }
            )
        )
    }
}

#Preview {
    TemplateEditScreen(
        arguments: TemplateEditScreenArguments(
            templateId: UUID()
        )
    )
    .previewable()
}
