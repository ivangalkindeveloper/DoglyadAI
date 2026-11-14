#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SubscriptionAutoRenewalDisablingPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SubscriptionAutoRenewalDisablingStateProtocol

        init(
            state: any SubscriptionAutoRenewalDisablingStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = SubscriptionAutoRenewalDisablingViewModel(
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
                arguments: SubscriptionAutoRenewalDisablingArguments(),
                disableAutoRenewal: {},
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                SubscriptionAutoRenewalDisablingBottomSheetView(
                    viewModel: model,
                )
            }.id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
