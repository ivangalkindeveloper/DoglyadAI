#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct TemplateEditPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any TemplateEditStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as TemplateEditInitializationErrorState, _ as TemplateEditErrorState: true
            default: false
            }

            let model = TemplateEditViewModel(
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
                arguments: TemplateEditArguments(
                    templateId: ModulePreviewFactory.template.id,
                ),
                onSaveTemplate: { _ in },
                onDeleteTemplate: { _ in },
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
            return TemplateEditScreenView(
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
