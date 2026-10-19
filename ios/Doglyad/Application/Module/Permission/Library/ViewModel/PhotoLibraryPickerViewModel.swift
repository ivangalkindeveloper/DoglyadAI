import Combine
import UIKit

@MainActor
final class PhotoLibraryPickerViewModel: DModuleViewModel<any PhotoLibraryPickerStateProtocol> {
    let selectionLimit: Int

    private let arguments: PhotoLibraryPickerArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: PhotoLibraryPickerArguments,
    ) {
        selectionLimit = arguments.selectionLimit
        self.arguments = arguments
        super.init(
            state: PhotoLibraryPickerState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
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
