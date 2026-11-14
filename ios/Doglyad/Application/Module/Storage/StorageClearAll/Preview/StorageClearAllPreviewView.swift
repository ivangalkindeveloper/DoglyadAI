#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct StorageClearAllPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any StorageClearAllStateProtocol

        init(
            state: any StorageClearAllStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = StorageClearAllViewModel(
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
                arguments: StorageClearAllArguments(
                    onConfirm: {},
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                StorageClearAllBottomSheetView(
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
