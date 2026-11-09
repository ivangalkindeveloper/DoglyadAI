import Combine
import DoglyadUI
import Foundation
import Router

@MainActor
final class PaywallViewModel: DModuleViewModel<any PaywallStateProtocol> {
    private let messager: DMessager
    private let isInitiallySubscribed: Bool
    private var isDismissalRequested = false
    private let repositoryFactory: SubscriptionRepositoryFactory
    private let purchase: (SubscriptionPlan) async throws -> SubscriptionPurchaseOutcome
    private let restorePurchases: () async throws -> SubscriptionStatus?
    private let checkPurchase: () async throws -> SubscriptionPurchaseOutcome
    private let waitForPaymentCheck: () async throws -> Void

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments _: PaywallArguments?,
        purchase: @escaping (SubscriptionPlan) async throws -> SubscriptionPurchaseOutcome,
        restorePurchases: @escaping () async throws -> SubscriptionStatus?,
        checkPurchase: @escaping () async throws -> SubscriptionPurchaseOutcome,
        waitForPaymentCheck: @escaping () async throws -> Void = {
            try await Task.sleep(
                for: .seconds(
                    3,
                ),
            )
        },
    ) {
        self.messager = messager
        isInitiallySubscribed = getSubscriptionStatus() != nil
        repositoryFactory = container.subscriptionRepositoryFactory
        self.purchase = purchase
        self.restorePurchases = restorePurchases
        self.checkPurchase = checkPurchase
        self.waitForPaymentCheck = waitForPaymentCheck
        super.init(
            state: PaywallCatalogLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .paywall,
            ),
        )
    }

    var isDismissible: Bool {
        !router.path.isEmpty
    }

    var isProcessing: Bool {
        switch state {
        case _ as PaywallCatalogLoadingState, _ as PaywallPurchaseLoadingState, _ as PaywallRestoreLoadingState: true
        default: false
        }
    }

    var isContinueEnabled: Bool {
        !isDismissalRequested && selectableContent?.selectedPlan != nil
    }

    private var selectableContent: PaywallContentState? {
        switch state {
        case let content as PaywallSuccessState: content
        case let failed as PaywallOperationErrorState: failed
        default: nil
        }
    }

    override func onInit() {
        requestCatalog()
    }

    override func onSubscriptionChanged(
        _ status: SubscriptionStatus?,
    ) {
        guard status != nil, !isDismissalRequested, !isInitiallySubscribed else {
            return
        }
        switch state {
        case _ as PaywallSuccessState, _ as PaywallCatalogErrorState, _ as PaywallCatalogLoadingState:
            dismissPaywall()
        default: break
        }
    }

    override func onDisappear() {
        super.onDisappear()
        switch state {
        case let purchasing as PaywallPurchaseLoadingState:
            emit(
                PaywallSuccessState(
                    copying: purchasing,
                ),
            )
        case let restoring as PaywallRestoreLoadingState:
            emit(
                restoring.previousState,
            )
        default: break
        }
    }

    func onTapClose() {
        guard !isDismissalRequested else {
            return
        }
        analytics.buttonTapped(
            .paywallCancel,
        )
        dismissPaywall()
    }

    func onSelectType(
        _ type: SubscriptionType,
    ) {
        guard !isDismissalRequested, let content = selectableContent,
              content.tiers.contains(
                  where: {
                      $0.id == type
                  },
              )
        else {
            return
        }
        guard content.selectedType != type else {
            return
        }
        guard let selectedID = content.plans.first(
            where: {
                $0.type == type
            },
        )?.id else {
            return
        }
        emit(
            PaywallSuccessState(
                tiers: content.tiers,
                plans: content.plans,
                selectedType: type,
                selectedPlanID: selectedID,
            ),
        )
    }

    func onTapPlan(
        _ plan: SubscriptionPlan,
    ) {
        guard !isDismissalRequested, let content = selectableContent,
              content.displayedPlans.contains(
                  plan,
              )
        else {
            return
        }
        emit(
            PaywallSuccessState(
                tiers: content.tiers,
                plans: content.plans,
                selectedType: content.selectedType,
                selectedPlanID: plan.id,
            ),
        )
    }

    func onTapRetry() {
        guard !isDismissalRequested else {
            return
        }
        switch state {
        case let content as PaywallContentState:
            requestCatalog(
                previous: content,
            )
        case _ as PaywallCatalogErrorState: requestCatalog()
        default: break
        }
    }

    func onTapRestore() {
        guard !isDismissalRequested else {
            return
        }
        guard !isProcessing, let previous = selectableContent else {
            return
        }
        analytics.buttonTapped(
            .paywallRestoreStarted,
        )
        if selectableContent?.selectedPlan?.source == .yookassa {
            coordinator.screen(
                .subscriptionRecovery,
            )
            return
        }
        let restoring = PaywallRestoreLoadingState(
            previousState: previous,
        )
        emit(
            restoring,
        )
        operationTask = Task {
            do {
                let status = try await restorePurchases()
                guard !Task.isCancelled, !isDismissalRequested, state === restoring else {
                    return
                }
                updateSubscriptionStatus(
                    status,
                )
                analytics.actionCompleted(
                    .subscriptionRestoreCompleted,
                )
                guard !Task.isCancelled, !isDismissalRequested else {
                    return
                }
                emit(
                    previous,
                )
                switch status {
                case .some: dismissPaywall()
                case .none: break
                }
            } catch {
                guard !Task.isCancelled, !isDismissalRequested, state === restoring else {
                    return
                }
                fail(
                    previous: previous,
                    description: l10n.text(
                        .subscriptionRestoreErrorDescription,
                    ),
                )
            }
        }
    }

    func onTapTerms() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentArguments(
                url: container.applicationConfig.termsAndConditionsUrl,
                title: l10n[
                    .termsAndConditionsTitle,
                ],
            ),
        )
    }

    func onTapPrivacyPolicy() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentArguments(
                url: container.applicationConfig.privacyPolicyUrl,
                title: l10n[
                    .privacyPolicyTitle,
                ],
            ),
        )
    }

    func onTapContinue() {
        guard !isDismissalRequested, let content = selectableContent, let plan = content.selectedPlan else {
            return
        }
        analytics.buttonTapped(
            .paywallPurchaseStarted,
            parameters: AnalyticsParameters(
                [.productId: .string(
                    plan.id,
                )],
            ),
        )
        let purchasing = PaywallPurchaseLoadingState(
            content: content,
            plan: plan,
        )
        emit(
            purchasing,
        )
        operationTask = Task {
            do {
                let initial = try await purchase(
                    plan,
                )
                let outcome = try await self.completePurchase(
                    initial,
                    purchasing: purchasing,
                )
                guard !Task.isCancelled, !isDismissalRequested, state === purchasing else {
                    return
                }
                switch outcome {
                case .pending: break
                case .cancelled:
                    emit(
                        PaywallSuccessState(
                            copying: content,
                        ),
                    )
                case let .completed(
                    status,
                ):
                    updateSubscriptionStatus(
                        status,
                    )
                    analytics.actionCompleted(
                        .subscriptionPurchaseCompleted,
                    )
                    guard !Task.isCancelled, !isDismissalRequested else {
                        return
                    }
                    emit(
                        PaywallSuccessState(
                            copying: content,
                        ),
                    )
                    dismissPaywall()
                }
            } catch {
                guard !Task.isCancelled, !isDismissalRequested, state === purchasing else {
                    return
                }
                fail(
                    previous: content,
                    description: l10n.text(
                        .subscriptionPurchaseErrorDescription,
                    ),
                )
            }
        }
    }

    private func completePurchase(
        _ initial: SubscriptionPurchaseOutcome,
        purchasing: PaywallPurchaseLoadingState,
    ) async throws -> SubscriptionPurchaseOutcome {
        var outcome = initial
        var isErrorReported = false
        while true {
            switch outcome {
            case .pending:
                try await waitForPaymentCheck()
                try Task.checkCancellation()
                guard !isDismissalRequested, state === purchasing else {
                    throw CancellationError()
                }
                do {
                    outcome = try await checkPurchase()
                    isErrorReported = false
                } catch {
                    guard !Task.isCancelled, !isDismissalRequested, state === purchasing else {
                        throw CancellationError()
                    }
                    if !isErrorReported {
                        messager.show(
                            type: .error,
                            title: l10n[
                                .errorUnknownTitle,
                            ],
                            description: l10n[
                                .subscriptionPaymentCheckErrorDescription,
                            ],
                        )
                        isErrorReported = true
                    }
                }
            case .completed, .cancelled: return outcome
            }
        }
    }

    private func dismissPaywall() {
        guard !isDismissalRequested else {
            return
        }
        isDismissalRequested = true
        cancelOperationTask()
        lastTask?.cancel()
        coordinator.dismissPaywall()
    }

    private func fail(
        previous: (any PaywallStateProtocol)?,
        description: String,
    ) {
        messager.show(
            type: .error,
            title: l10n[
                .errorUnknownTitle,
            ],
            description: LocalizedStringResource(
                stringLiteral: description,
            ),
        )
        switch previous {
        case let failed as PaywallOperationErrorState:
            emit(
                PaywallOperationErrorState(
                    errorDescription: description,
                    previousState: failed.previousState,
                ),
            )
        case let content as PaywallContentState:
            emit(
                PaywallOperationErrorState(
                    errorDescription: description,
                    previousState: content,
                ),
            )
        default:
            emit(
                PaywallCatalogErrorState(
                    errorDescription: description,
                ),
            )
        }
    }

    private func requestCatalog(
        previous: PaywallContentState? = nil,
    ) {
        lastTask?.cancel()
        emit(
            PaywallCatalogLoadingState(
                previousState: previous,
            ),
        )
        let loading = state
        handle {
            let repository = await self.repositoryFactory.make()
            try Task.checkCancellation()
            return try await repository.fetchCatalog()
        } onMainSuccess: { catalog in
            guard !Task.isCancelled, !self.isDismissalRequested, self.state === loading else {
                return
            }
            guard !catalog.plans.isEmpty, !catalog.tiers.isEmpty else {
                self.fail(
                    previous: nil,
                    description: self.l10n.text(
                        .subscriptionOfferingsUnavailableDescription,
                    ),
                )
                return
            }
            let plans = catalog.plans.sorted {
                let first = self.periodOrder(
                    $0.period,
                )
                let second = self.periodOrder(
                    $1.period,
                )
                return first == second ? $0.id < $1.id : first < second
            }
            let preferredType = previous?.selectedType ?? .pro
            let selectedType = plans.contains {
                $0.type == preferredType
            } ? preferredType : plans[
                0,
            ].type
            let available = plans.filter {
                $0.type == selectedType
            }
            let selectedID = available.first {
                $0.id == previous?.selectedPlanID
            }?.id ?? available.first?.id
            self.emit(
                PaywallSuccessState(
                    tiers: catalog.tiers,
                    plans: plans,
                    selectedType: selectedType,
                    selectedPlanID: selectedID,
                ),
            )
        } onMainApiError: { _ in
            guard !Task.isCancelled, !self.isDismissalRequested, self.state === loading else {
                return
            }
            self.fail(
                previous: previous,
                description: self.l10n.text(
                    .subscriptionOfferingsUnavailableDescription,
                ),
            )
        } onMainConnectionError: { _ in
            guard !Task.isCancelled, !self.isDismissalRequested, self.state === loading else {
                return
            }
            self.fail(
                previous: previous,
                description: self.l10n.text(
                    .subscriptionOfferingsUnavailableDescription,
                ),
            )
        } onMainUnknownError: { _ in
            guard !Task.isCancelled, !self.isDismissalRequested, self.state === loading else {
                return
            }
            self.fail(
                previous: previous,
                description: self.l10n.text(
                    .subscriptionOfferingsUnavailableDescription,
                ),
            )
        }
    }

    private func periodOrder(
        _ period: SubscriptionPeriod,
    ) -> Int {
        switch period {
        case .annual: 0
        case .sixMonth: 1
        case .monthly: 2
        case .weekly: 3
        }
    }
}
