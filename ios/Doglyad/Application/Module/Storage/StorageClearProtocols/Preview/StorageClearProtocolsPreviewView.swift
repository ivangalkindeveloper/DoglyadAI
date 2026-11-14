#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct StorageClearProtocolsPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any StorageClearProtocolsStateProtocol

        init(
            state: any StorageClearProtocolsStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = StorageClearProtocolsViewModel(
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
                arguments: StorageClearProtocolsArguments(
                    onConfirm: {},
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                StorageClearProtocolsBottomSheetView(
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
