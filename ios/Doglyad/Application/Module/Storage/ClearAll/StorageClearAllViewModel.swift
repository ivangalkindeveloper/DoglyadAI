@MainActor
final class StorageClearAllViewModel: DViewModel {
    private let arguments: StorageClearAllArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: StorageClearAllArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.storageClearAll)
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(.storageClearAllConfirm)
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
