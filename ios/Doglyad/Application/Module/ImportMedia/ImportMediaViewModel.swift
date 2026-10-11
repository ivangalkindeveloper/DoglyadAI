import Combine
import Router

@MainActor
final class ImportMediaViewModel: DModuleViewModel {
    private let arguments: ImportMediaArguments
    private var actionAfterDismiss: (() -> Void)?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: ImportMediaArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
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
                .importMedia,
            ),
        )
    }

    func onDisappear() {
        let action = actionAfterDismiss
        actionAfterDismiss = nil
        action?()
    }

    func onTapCamera() {
        guard actionAfterDismiss == nil else { return }

        actionAfterDismiss = arguments.onTapCamera
        coordinator.dismissSheet()
    }

    func onTapGallery() {
        guard actionAfterDismiss == nil else { return }

        actionAfterDismiss = arguments.onTapGallery
        coordinator.dismissSheet()
    }
}
