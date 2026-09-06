import Foundation
import UIKit

@MainActor
final class NewVersionViewModel: DViewModel {
    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.newVersion)
        )
    }

    func onTapUpdate() {
        analytics.buttonTapped(.newVersionUpdate)
        let id = container.applicationConfig.appStoreId
        UIApplication.openAppStore(
            appleUpdateUrl: container.applicationConfig.appleUpdateUrl,
            id: id
        )
    }
}
