#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct ImportMediaPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any ImportMediaStateProtocol

        init(
            state: any ImportMediaStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = ImportMediaViewModel(
                container: container,
                router: router,
                arguments: ImportMediaArguments(
                    onTapCamera: {},
                    onTapGallery: {},
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
                ImportMediaBottomSheetView(
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
