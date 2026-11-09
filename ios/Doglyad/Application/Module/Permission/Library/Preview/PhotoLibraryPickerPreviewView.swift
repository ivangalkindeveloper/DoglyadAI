#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct PhotoLibraryPickerPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any PhotoLibraryPickerStateProtocol

        var body: some View {
            let model = PhotoLibraryPickerViewModel(
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
                arguments: PhotoLibraryPickerArguments(
                    selectionLimit: 6,
                    onComplete: { _ in },
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                PhotoLibraryPickerBottomSheetView(
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
