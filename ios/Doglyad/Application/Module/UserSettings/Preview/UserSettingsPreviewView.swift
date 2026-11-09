#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct UserSettingsPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any UserSettingsStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as UserSettingsErrorState: true
            default: false
            }

            let model = UserSettingsViewModel(
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
                getInitialIsRecommendationsIncluded: {
                    true
                },
                getInitialIsPhotoRemarks: {
                    true
                },
                getInitialIsDescriptionRemarks: {
                    true
                },
                onSaved: { _, _, _, _ in },
            )

            model.preparePreview(
                state: state,
            )
            return UserSettingsScreenView(
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
