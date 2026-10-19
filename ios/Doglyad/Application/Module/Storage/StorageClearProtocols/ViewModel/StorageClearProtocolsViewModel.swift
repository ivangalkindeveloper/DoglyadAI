import Combine

@MainActor
final class StorageClearProtocolsViewModel: DModuleViewModel<any StorageClearProtocolsStateProtocol> {
    private let arguments: StorageClearProtocolsArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: StorageClearProtocolsArguments?,
    ) {
        self.arguments = arguments
        super.init(
            state: StorageClearProtocolsState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
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
