import DoglyadUI
import Router
import SwiftUI

struct TemplateAddScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: TemplateAddScreenArguments?

    var body: some View {
        TemplateAddScreenView(
            viewModel: TemplateAddViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                messager: messager,
                onSaveTemplate: { [ultrasoundViewModel, arguments] template in
                    ultrasoundViewModel.saveTemplate(
                        template,
                        onChanged: {
                            arguments?.onTemplatesChanged?()
                            arguments?.onAddSuccess?(template)
                        }
                    )
                }
            )
        )
    }
}

#Preview {
    TemplateAddScreen(
        arguments: nil
    )
    .previewable()
}
