@MainActor
final class TemplateDeleteViewModel: DViewModel {
    private let arguments: TemplateDeleteArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: TemplateDeleteArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.templateDelete)
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(.templateDeleteConfirm)
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
