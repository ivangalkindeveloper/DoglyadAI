#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct LegalUpdatePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any LegalUpdateStateProtocol
        var isLegalAccepted = false

        var body: some View {
            let isErrorPresented = switch state {
            case _ as LegalUpdateErrorState: true
            default: false
            }

            let model = LegalUpdateViewModel(
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

            model.isLegalAccepted = isLegalAccepted

            model.preparePreview(
                state: state,
            )
            return LegalUpdateScreenView(
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
