@MainActor
final class StorageClearProtocolsViewModel: DViewModel {
    private let arguments: StorageClearProtocolsArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: StorageClearProtocolsArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.storageClearProtocols)
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(.storageClearProtocolsConfirm)
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
