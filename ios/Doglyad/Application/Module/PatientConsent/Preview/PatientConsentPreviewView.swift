#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct PatientConsentPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: PatientConsentInitialState
        var isErrorPresented = false

        var body: some View {
            let model = PatientConsentViewModel(
                messager: messager,
                container: container,
                router: router,
                arguments: PatientConsentArguments(
                    onConfirm: {},
                ),
                onSaved: { _ in },
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
                PatientConsentBottomSheetView(
                    viewModel: model,
                )
            }
            .previewError(
                isPresented: isErrorPresented,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
