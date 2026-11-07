#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct TemplateAddPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any TemplateAddStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as TemplateAddFailedState: true
            default: false
            }

            let model = TemplateAddViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                messager: messager,
                onSaveTemplate: { _ in },
            )

            model.nameTextController.setText(
                ModulePreviewFactory.template.name,
            )

            model.templateTextController.setText(
                ModulePreviewFactory.template.content,
            )

            model.preparePreview(
                state: state,
            )
            return TemplateAddScreenView(
                viewModel: model,
            )
            .previewError(
                isPresented: isErrorPresented,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
