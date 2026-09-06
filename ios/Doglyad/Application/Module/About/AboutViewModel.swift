@MainActor
final class AboutViewModel: DViewModel {
    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.about)
        )
    }

    var contactEmail: String {
        container.applicationConfig.contactEmail
    }

    var version: String {
        container.version
    }

    func onTapEmail() {
        analytics.buttonTapped(.aboutEmail)
    }
}
