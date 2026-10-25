import Combine

@MainActor
final class TemplateDeleteViewModel: DModuleViewModel<any TemplateDeleteStateProtocol> {
    private let arguments: TemplateDeleteArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: TemplateDeleteArguments?,
    ) {
        self.arguments = arguments
        super.init(
            state: TemplateDeleteState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .templateDelete,
            ),
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(
            .templateDeleteConfirm,
        )
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
