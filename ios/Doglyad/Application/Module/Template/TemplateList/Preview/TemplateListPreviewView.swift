#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct TemplateListPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any TemplateListStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as TemplateListErrorState: true
            default: false
            }

            let model = TemplateListViewModel(
                messager: DMessager(),
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
            )

            model.preparePreview(
                state: state,
            )
            return TemplateListScreenView(
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
