import RevenueCat
import Router

@MainActor
final class SubscriptionPaywallViewModel: DViewModel {
    private let arguments: SubscriptionPaywallArguments?
    private let onRefreshStatus: () async -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SubscriptionPaywallArguments?,
        onRefreshStatus: @escaping () async -> Void
    ) {
        self.arguments = arguments
        self.onRefreshStatus = onRefreshStatus
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.subscriptionPaywall)
        )
    }

    func onPurchaseStarted(
        productId: String
    ) {
        analytics.buttonTapped(
            .subscriptionPaywallPurchaseStarted,
            parameters: AnalyticsParameters([
                .productId: .string(productId),
            ])
        )
    }

    func onPurchaseCompleted() {
        analytics.actionCompleted(.subscriptionPurchaseCompleted)
        handle {
            await self.onRefreshStatus()
        }
    }

    func onRestoreStarted() {
        analytics.buttonTapped(.subscriptionPaywallRestoreStarted)
    }

    func onRestoreCompleted() {
        analytics.actionCompleted(.subscriptionRestoreCompleted)
        handle {
            await self.onRefreshStatus()
        }
    }

    func onRequestedDismissal() {
        analytics.buttonTapped(.subscriptionPaywallCancel)
        coordinator.dismissPaywall()
    }
}
