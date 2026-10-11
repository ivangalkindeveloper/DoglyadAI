import Combine

@MainActor
final class StorageClearProtocolsViewModel: DModuleViewModel {
    private let arguments: StorageClearProtocolsArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: StorageClearProtocolsArguments?,
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .storageClearProtocols,
            ),
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(
            .storageClearProtocolsConfirm,
        )
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
