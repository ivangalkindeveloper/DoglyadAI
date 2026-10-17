import Combine
import Foundation
import UIKit

@MainActor
final class PermissionViewModel: DModuleViewModel<any PermissionStateProtocol> {
    private let kind: PermissionArguments.Kind

    var title: LocalizedStringResource {
        switch kind {
        case .camera: l10n[
                .permissionCameraTitle,
            ]
        case .photoLibrary: l10n[
                .permissionPhotoLibraryTitle,
            ]
        case .speech: l10n[
                .permissionSpeechTitle,
            ]
        }
    }

    var description: LocalizedStringResource {
        switch kind {
        case .camera: l10n[
                .permissionCameraDescription,
            ]
        case .photoLibrary: l10n[
                .permissionPhotoLibraryDescription,
            ]
        case .speech: l10n[
                .permissionSpeechDescription,
            ]
        }
    }

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: PermissionArguments,
    ) {
        kind = arguments.kind
        super.init(
            state: PermissionState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                arguments.kind.analyticsDestination,
            ),
        )
    }

    func onTapOpenSettings() {
        UIApplication.openSettings()
    }
}
