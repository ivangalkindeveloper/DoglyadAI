#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct NewVersionPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any NewVersionStateProtocol

        init(
            state: any NewVersionStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = NewVersionViewModel(
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
            return NewVersionScreenView(
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
