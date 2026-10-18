import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
class DModuleViewModel<State>: DStateViewModel<State> {
    private var isInitialized = false

    let container: DependencyContainer
    let router: DRouter
    @Published private(set) var subscriptionStatus: SubscriptionStatus?
    private var subscriptionObservation: AnyCancellable?
    private let getNeuralModelSettings: () -> NeuralModelSettings
    private let onRequestCountIncremented: () -> Void
    private let onSubscriptionStatusUpdated: (SubscriptionStatus?) -> Void
    let coordinator: Coordinator
    private let analyticsDestination: AnalyticsRouteDestination
    private let analyticsParameters: AnalyticsParameters

    init(
        state: State,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        analyticsDestination: AnalyticsRouteDestination,
        analyticsParameters: AnalyticsParameters = .empty,
    ) {
        self.container = container
        self.router = router
        subscriptionStatus = getSubscriptionStatus()
        self.getNeuralModelSettings = getNeuralModelSettings
        self.onRequestCountIncremented = onRequestCountIncremented
        self.onSubscriptionStatusUpdated = onSubscriptionStatusUpdated
        self.analyticsDestination = analyticsDestination
        self.analyticsParameters = analyticsParameters
        coordinator = Coordinator(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
        )
        super.init(
            state: state,
        )
        subscriptionObservation = observeSubscriptionStatus { [weak self] status in
            guard let self else { return }
            subscriptionStatus = status
            onSubscriptionChanged(
                status,
            )
        }
    }

    var analytics: AnalyticsManager { container.analytics }
    var l10n: L10N { container.l10n }

    var availableRequestCount: Int { subscriptionStatus?.availableCountPerDay ?? 0 }
    var neuralModelSettings: NeuralModelSettings { getNeuralModelSettings() }

    final func onAppear() {
        switch analyticsDestination {
        case let .screen(
            screen,
        ):
            analytics.screenViewed(
                screen,
                parameters: analyticsParameters,
            )
        case let .bottomSheet(
            bottomSheet,
        ):
            analytics.bottomSheetViewed(
                bottomSheet,
                parameters: analyticsParameters,
            )
        }

        guard !isInitialized else { return }
        isInitialized = true
        onInit()
    }

    func onInit() {}

    func onSubscriptionChanged(
        _: SubscriptionStatus?,
    ) {}

    func subscriptionAvailability(
        of feature: PaidFeature,
    ) -> SubscriptionFeatureAvailability {
        subscriptionStatus?.availability(
            of: feature,
        ) ?? .unavailable
    }

    func incrementRequestCount() {
        onRequestCountIncremented()
    }

    func updateSubscriptionStatus(
        _ status: SubscriptionStatus?,
    ) {
        onSubscriptionStatusUpdated(
            status,
        )
    }
}
