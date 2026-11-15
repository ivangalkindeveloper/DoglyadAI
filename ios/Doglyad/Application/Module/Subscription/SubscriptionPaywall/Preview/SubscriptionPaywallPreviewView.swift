#if DEBUG
    import Router
    import SwiftUI

    struct SubscriptionPaywallPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SubscriptionPaywallStateProtocol
        var isPurchaseSuccessPresented: Bool = false

        init(
            state: any SubscriptionPaywallStateProtocol,
            isPurchaseSuccessPresented: Bool = false,
        ) {
            self.state = state
            self.isPurchaseSuccessPresented = isPurchaseSuccessPresented
        }

        var body: some View {
            let errorDescription: String? = switch state {
            case let error as SubscriptionPaywallCatalogErrorState: error.errorDescription
            case let error as SubscriptionPaywallOperationErrorState: error.errorDescription
            default: nil
            }

            let model = SubscriptionPaywallPreviewFactory.makeViewModel(
                container: container,
                router: router,
            )

            model.preparePreview(
                state: state,
            )
            return SubscriptionPaywallScreenView(
                viewModel: model,
            )
            .previewError(
                isPresented: errorDescription != nil,
                description: errorDescription,
            )
            .previewMessage(
                type: .success,
                title: isPurchaseSuccessPresented ? .subscriptionPaywallPurchaseSuccessTitle : nil,
                description: isPurchaseSuccessPresented ? .subscriptionPaywallPurchaseSuccessDescription : nil,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
