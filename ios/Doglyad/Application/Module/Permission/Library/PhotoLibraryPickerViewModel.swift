import Combine
import UIKit

@MainActor
final class PhotoLibraryPickerViewModel: DModuleViewModel {
    private let arguments: PhotoLibraryPickerArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: PhotoLibraryPickerArguments,
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
                .photoLibraryPicker,
            ),
            analyticsParameters: AnalyticsParameters(
                [
                    .selectionLimit: .int(
                        arguments.selectionLimit,
                    ),
                ],
            ),
        )
    }

    var selectionLimit: Int {
        arguments.selectionLimit
    }

    func onComplete(
        _ images: [UIImage],
    ) {
        if images.isEmpty {
            analytics.buttonTapped(
                .photoLibraryCancel,
            )
        } else {
            analytics.buttonTapped(
                .photoLibraryComplete,
                parameters: AnalyticsParameters(
                    [
                        .itemCount: .int(
                            images.count,
                        ),
                    ],
                ),
            )
        }
        coordinator.dismissSheet()
        arguments.onComplete(
            images,
        )
    }
}
