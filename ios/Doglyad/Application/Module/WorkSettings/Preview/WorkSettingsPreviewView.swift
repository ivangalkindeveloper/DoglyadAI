#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct WorkSettingsPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any WorkSettingsStateProtocol
        var isNeedPatientConsent: Bool = true

        var body: some View {
            let isErrorPresented = switch state {
            case _ as WorkSettingsErrorState: true
            default: false
            }

            let model = WorkSettingsViewModel(
                container: container,
                messager: messager,
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
                getInitialEmail: {
                    "doctor@example.com"
                },
                getInitialIsNeedPatientConsent: {
                    isNeedPatientConsent
                },
                getInitialIsRecommendationsIncluded: {
                    true
                },
                getInitialIsPhotoRemarks: {
                    true
                },
                getInitialIsDescriptionRemarks: {
                    true
                },
                onSaved: { _, _, _, _, _ in },
            )

            model.preparePreview(
                state: state,
            )
            return WorkSettingsScreenView(
                viewModel: model,
            )
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
