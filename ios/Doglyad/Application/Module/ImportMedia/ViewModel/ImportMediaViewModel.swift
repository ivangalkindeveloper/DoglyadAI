import Combine
import Router

@MainActor
final class ImportMediaViewModel: DModuleViewModel<any ImportMediaStateProtocol> {
    private let arguments: ImportMediaArguments
    private var actionAfterDismiss: (() -> Void)?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: ImportMediaArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        self.arguments = arguments
        super.init(
            state: ImportMediaDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .importMedia,
            ),
        )
    }

    override func onDisappear() {
        super.onDisappear()
        let action = actionAfterDismiss
        actionAfterDismiss = nil
        action?()
    }

    func onTapCamera() {
        actionAfterDismiss = arguments.onTapCamera
        coordinator.dismissSheet()
    }

    func onTapGallery() {
        actionAfterDismiss = arguments.onTapGallery
        coordinator.dismissSheet()
    }
}
