import Combine

@MainActor
final class StorageClearAllViewModel: DModuleViewModel {
    private let arguments: StorageClearAllArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: StorageClearAllArguments?,
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
                .storageClearAll,
            ),
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(
            .storageClearAllConfirm,
        )
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
