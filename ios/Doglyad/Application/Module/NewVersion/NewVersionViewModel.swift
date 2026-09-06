import Foundation
import UIKit

@MainActor
final class NewVersionViewModel: DViewModel {
    override init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    func onTapUpdate() {
        let id = container.applicationConfig.appStoreId
        UIApplication.openAppStore(
            appleUpdateUrl: container.applicationConfig.appleUpdateUrl,
            id: id
        )
    }
}
