import Router

@MainActor
final class RequestLimitViewModel: DViewModel {
    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.requestLimitExceeded)
        )
    }

    func onTapUpgrade() {
        analytics.buttonTapped(.requestLimitUpgrade)
        coordinator.showPaywall(dismissingSheet: true)
    }

    func onTapBack() {
        analytics.buttonTapped(.requestLimitBack)
        coordinator.dismissSheet()
    }
}
