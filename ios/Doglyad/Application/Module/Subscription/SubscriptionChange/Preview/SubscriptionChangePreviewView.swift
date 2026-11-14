#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SubscriptionChangePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SubscriptionChangeStateProtocol
        let source: SubscriptionSource

        init(
            state: any SubscriptionChangeStateProtocol,
            source: SubscriptionSource,
        ) {
            self.state = state
            self.source = source
        }

        var body: some View {
            let model = SubscriptionChangeViewModel(
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
                arguments: SubscriptionChangeArguments(
                    source: source,
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                SubscriptionChangeBottomSheetView(
                    viewModel: model,
                )
            }.id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
