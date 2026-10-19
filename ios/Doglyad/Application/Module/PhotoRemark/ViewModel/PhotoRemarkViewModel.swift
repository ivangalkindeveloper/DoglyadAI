import Combine
import Foundation

@MainActor
final class PhotoRemarkViewModel: DModuleViewModel<any PhotoRemarkStateProtocol> {
    let title: String
    let description: String

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: PhotoRemarkArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        title = arguments.title
        description = arguments.description
        super.init(
            state: PhotoRemarkState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .photoRemark,
            ),
        )
    }

    func onTapBack() {
        coordinator.dismissSheet()
    }
}
