import Combine
import Foundation

@MainActor
final class PhotoRemarkViewModel: DModuleViewModel {
    let title: String
    let description: String

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: PhotoRemarkArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        title = arguments.title
        description = arguments.description
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
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
