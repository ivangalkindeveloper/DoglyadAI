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
            subscription: subscription
        )
    }

    func onCompleted() {
        handle {
            await self.onRefreshStatus()
        }
    }

    func onRequestedDismissal() {
        coordinator.dismissPaywall()
    }
}
