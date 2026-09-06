import DoglyadNetwork
import Foundation
import Handler
import NestedObservableObject

@MainActor
class DViewModel: Handler<DHttpApiError, DHttpConnectionError>, ObservableObject {
    private var isInitialized = false

    let container: DependencyContainer
    let router: DRouter
    @NestedObservableObject var subscription: SubscriptionViewModel
    let coordinator: Coordinator

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        self.container = container
        self.router = router
        _subscription = NestedObservableObject(wrappedValue: subscription)
        coordinator = Coordinator(
            container: container,
            router: router,
            getSubscriptionStatus: { subscription.status },
            onSubscriptionStatusUpdated: { subscription.update(status: $0) }
        )
        super.init()
    }

    final func onAppear() {
        guard !isInitialized else { return }
        isInitialized = true
        onInit()
    }

    func onInit() {}
}
