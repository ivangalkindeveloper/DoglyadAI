import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
class DModuleViewModel<State>: DStateViewModel<State> {
    private var isInitialized = false

    #if DEBUG
        private(set) var isPreviewSnapshot = false

    #endif

    let container: DependencyContainer
    let router: DRouter
    @Published private(set) var subscriptionStatus: SubscriptionStatus?
    var operationTask: Task<Void, Never>?
    private var subscriptionObservation: AnyCancellable?
    private let observeSubscriptionStatus: (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable
    private let getSettingsAI: () -> SettingsAI
    private let onRefreshSubscriptionStatus: () async -> Void
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
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        analyticsDestination: AnalyticsRouteDestination,
        analyticsParameters: AnalyticsParameters = .empty,
    ) {
        self.container = container
        self.router = router
        subscriptionStatus = getSubscriptionStatus()
        self.observeSubscriptionStatus = observeSubscriptionStatus
        self.getSettingsAI = getSettingsAI
        self.onRefreshSubscriptionStatus = onRefreshSubscriptionStatus
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
    }

    var analytics: AnalyticsManager {
        container.analytics
    }

    var l10n: L10N {
        container.l10n
    }

    var availableRequestCount: Int {
        subscriptionStatus?.availableCountPerDay ?? 0
    }

    var settingsAI: SettingsAI {
        getSettingsAI()
    }

    #if DEBUG
        /// Keep Canvas snapshots in their selected phase without starting module services.
        final func preparePreview(
            state: State,
        ) {
            isPreviewSnapshot = true
            emit(
                state,
                animation: nil,
            )
        }
    #endif

    final func onAppear() {
        #if DEBUG
            guard !isPreviewSnapshot else {
                return
            }
        #endif
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

        if subscriptionObservation == nil {
            subscriptionObservation = observeSubscriptionStatus { [weak self] status in
                guard let self else {
                    return
                }
                subscriptionStatus = status
                onSubscriptionChanged(
                    status,
                )
            }
        }
        guard !isInitialized else {
            return
        }
        isInitialized = true
        #if DEBUG && DOGLYAD_REGRESSION
            // Child tasks inherit the module scope; unrelated startup reads stay real.
            RegressionRepositoryFaults.$module.withValue(
                String(
                    describing: type(
                        of: self,
                    ),
                ),
            ) {
                onInit()
            }
        #else
            onInit()
        #endif
    }

    func onInit() {}

    func onDisappear() {
        cancelOperationTask()
        subscriptionObservation?.cancel()
        subscriptionObservation = nil
    }

    final func cancelOperationTask() {
        operationTask?.cancel()
        operationTask = nil
    }

    func onSubscriptionChanged(
        _: SubscriptionStatus?,
    ) {}

    func subscriptionAvailability(
        of feature: SubscriptionPaidFeature,
    ) -> SubscriptionFeatureAvailability {
        subscriptionStatus?.availability(
            of: feature,
        ) ?? .unavailable
    }

    func refreshStatus() async {
        await onRefreshSubscriptionStatus()
    }

    func updateSubscriptionStatus(
        _ status: SubscriptionStatus?,
    ) {
        onSubscriptionStatusUpdated(
            status,
        )
    }
}
