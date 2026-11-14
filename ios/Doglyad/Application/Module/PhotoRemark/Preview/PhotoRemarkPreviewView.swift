#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct PhotoRemarkPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any PhotoRemarkStateProtocol

        init(
            state: any PhotoRemarkStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = PhotoRemarkViewModel(
                container: container,
                router: router,
                arguments: PhotoRemarkArguments(
                    title: "Очаговое образование",
                    description: "Гипоэхогенное образование с чёткими контурами. Размеры: 8 × 6 мм.",
                ),
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
                PhotoRemarkBottomSheetView(
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
