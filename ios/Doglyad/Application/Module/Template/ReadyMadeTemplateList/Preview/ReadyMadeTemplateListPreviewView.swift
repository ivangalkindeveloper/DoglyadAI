#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct ReadyMadeTemplateListPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any ReadyMadeTemplateListStateProtocol

        var body: some View {
            let model = ReadyMadeTemplateListViewModel(
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
                arguments: ReadyMadeTemplateListArguments(
                    onTemplateSelected: { _ in },
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ReadyMadeTemplateListScreenView(
                viewModel: model,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
