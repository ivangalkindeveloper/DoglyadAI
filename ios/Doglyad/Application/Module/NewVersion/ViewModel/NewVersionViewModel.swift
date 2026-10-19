import Combine
import Foundation
import UIKit

@MainActor
final class NewVersionViewModel: DModuleViewModel<any NewVersionStateProtocol> {
    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        super.init(
            state: NewVersionState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .newVersion,
            ),
        )
    }

    func onTapUpdate() {
        analytics.buttonTapped(
            .newVersionUpdate,
        )
        let id = container.applicationConfig.appStoreId
        UIApplication.openAppStore(
            appleUpdateUrl: container.applicationConfig.appleUpdateUrl,
            id: id,
        )
    }
}
