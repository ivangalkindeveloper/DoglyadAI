#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct RequestLimitExceededPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any RequestLimitExceededStateProtocol

        init(
            state: any RequestLimitExceededStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = RequestLimitExceededViewModel(
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
            return ModuleBottomSheetPreviewView {
                RequestLimitExceededBottomSheetView(
                    viewModel: model,
                )
            }
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
