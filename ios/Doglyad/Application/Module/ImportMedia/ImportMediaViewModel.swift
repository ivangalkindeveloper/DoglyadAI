import Router

@MainActor
final class ImportMediaViewModel: DViewModel {
    private let arguments: ImportMediaArguments
    private var actionAfterDismiss: (() -> Void)?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: ImportMediaArguments,
        subscription: SubscriptionViewModel
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.importMedia)
        )
    }

    func onTapCamera() {
        guard actionAfterDismiss == nil else { return }

        actionAfterDismiss = arguments.onTapCamera
        coordinator.dismissSheet()
    }

    func onTapGallery() {
        guard actionAfterDismiss == nil else { return }

        actionAfterDismiss = arguments.onTapGallery
        coordinator.dismissSheet()
    }

    func onDisappear() {
        let action = actionAfterDismiss
        actionAfterDismiss = nil
        action?()
    }
}
