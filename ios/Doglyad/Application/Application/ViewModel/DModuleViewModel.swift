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
    private var localOperationID: UUID?
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
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
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
        coordinator = Coordinator(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
        )
        self.analyticsDestination = analyticsDestination
        self.analyticsParameters = analyticsParameters
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

    /// Local persistence keeps the current presentation. The task owns duplicate/stale guards.
    final func performLocalOperation<Value>(
        _ execute: @escaping @MainActor () async throws -> Value,
        onSuccess: @escaping @MainActor (Value) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void,
    ) {
        guard operationTask == nil else {
            return
        }
        let id = UUID()
        localOperationID = id
        let task = Task { @MainActor [weak self] in
            defer {
                if self?.localOperationID == id {
                    self?.localOperationID = nil
                    self?.operationTask = nil
                }
            }
            do {
                try Task.checkCancellation()
                let value = try await execute()
                guard let self, !Task.isCancelled, localOperationID == id else {
                    return
                }
                onSuccess(
                    value,
                )
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled, localOperationID == id else {
                    return
                }
                onFailure(
                    error,
                )
            }
        }
        operationTask = task
        lastTask = task
    }

    final func cancelOperationTask() {
        localOperationID = nil
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
