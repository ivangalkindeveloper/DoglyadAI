import Router

@MainActor
final class RequestLimitViewModel: DViewModel {
    override init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    func onTapUpgrade() {
        coordinator.showPaywall(dismissingSheet: true)
    }

    func onTapBack() {
        coordinator.dismissSheet()
    }
}
