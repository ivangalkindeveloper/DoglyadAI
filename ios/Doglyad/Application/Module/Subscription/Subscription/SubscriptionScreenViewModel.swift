import Router

@MainActor
final class SubscriptionScreenViewModel: DViewModel {
    private let arguments: SubscriptionScreenArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SubscriptionScreenArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    func onTapBack() {
        coordinator.pop()
    }

    func onTapChangeType() {
        coordinator.screen(.subscriptionPaywall)
    }

    func onTapSupportCenter() {
        coordinator.sheet(.subscriptionCustomerCenter)
    }
}
