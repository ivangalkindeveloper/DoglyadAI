#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct MenuPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any MenuStateProtocol
        var reportsCount: Int? = 12

        init(
            state: any MenuStateProtocol,
            reportsCount: Int? = 12,
        ) {
            self.state = state
            self.reportsCount = reportsCount
        }

        var body: some View {
            let model = MenuViewModel(
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

            model.reportsCount = reportsCount

            model.preparePreview(
                state: state,
            )
            return MenuScreenView(
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
