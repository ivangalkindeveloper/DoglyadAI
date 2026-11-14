#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct StorageClearSpeechModelPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any StorageClearSpeechModelStateProtocol

        init(
            state: any StorageClearSpeechModelStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = StorageClearSpeechModelViewModel(
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
                arguments: StorageClearSpeechModelArguments(
                    onConfirm: {},
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                StorageClearSpeechModelBottomSheetView(
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
