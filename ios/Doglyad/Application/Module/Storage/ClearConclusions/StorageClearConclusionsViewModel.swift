@MainActor
final class StorageClearConclusionsViewModel: DViewModel {
    private let arguments: StorageClearConclusionsArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: StorageClearConclusionsArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.storageClearConclusions)
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(.storageClearConclusionsConfirm)
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
