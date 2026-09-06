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
    var analytics: AnalyticsManager { container.analytics }
    private let analyticsDestination: AnalyticsRouteDestination
    private let analyticsParameters: AnalyticsParameters

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        analyticsDestination: AnalyticsRouteDestination,
        analyticsParameters: AnalyticsParameters = .empty
    ) {
        self.container = container
        self.router = router
        _subscription = NestedObservableObject(wrappedValue: subscription)
        self.analyticsDestination = analyticsDestination
        self.analyticsParameters = analyticsParameters
        coordinator = Coordinator(
            container: container,
            router: router,
            getSubscriptionStatus: { subscription.status },
            onSubscriptionStatusUpdated: { subscription.update(status: $0) }
        )
        super.init()
    }

    final func onAppear() {
        switch analyticsDestination {
        case let .screen(screen):
            analytics.screenViewed(screen, parameters: analyticsParameters)
        case let .bottomSheet(bottomSheet):
            analytics.bottomSheetViewed(bottomSheet, parameters: analyticsParameters)
        }

        guard !isInitialized else { return }
        isInitialized = true
        onInit()
    }

    func onInit() {}
}
