#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct OnBoardingPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any OnBoardingStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as OnBoardingErrorState: true
            default: false
            }

            let model = OnBoardingViewModel(
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
            )

            model.preparePreview(
                state: state,
            )
            return OnBoardingScreenView(
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
