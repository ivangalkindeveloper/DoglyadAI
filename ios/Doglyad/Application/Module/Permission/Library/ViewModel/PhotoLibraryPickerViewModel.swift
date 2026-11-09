import Combine
import DoglyadUI
import UIKit

@MainActor
final class PhotoLibraryPickerViewModel: DModuleViewModel<any PhotoLibraryPickerStateProtocol> {
    private let messager: DMessager
    let selectionLimit: Int
    private let arguments: PhotoLibraryPickerArguments

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: PhotoLibraryPickerArguments,
    ) {
        self.messager = messager
        selectionLimit = arguments.selectionLimit
        self.arguments = arguments
        super.init(
            state: PhotoLibraryPickerDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
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
        isSomeImagesUnavailable: Bool,
    ) {
        if isSomeImagesUnavailable {
            messager.showUnknownError(
                l10n: l10n,
            )
        }
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
