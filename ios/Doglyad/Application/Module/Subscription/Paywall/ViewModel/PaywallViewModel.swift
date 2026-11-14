import Combine
import DoglyadUI
import Foundation
import Router
import SwiftUI

@MainActor
final class PaywallViewModel: DModuleViewModel<any PaywallStateProtocol> {
    private let messager: DMessager
    private let isInitiallySubscribed: Bool
    private let presentationPath: NavigationPath
    private let repositoryFactory: SubscriptionRepositoryFactoryProtocol
    private let purchase: (SubscriptionPlan, Bool) async throws -> SubscriptionPurchaseOutcome
    private let restorePurchases: () async throws -> SubscriptionRestoreStrategy
    private let checkPurchase: () async throws -> SubscriptionPurchaseOutcome
    private var paymentCheckID: UUID?
    private var paymentCheckTask: Task<Void, Never>?
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
        purchase: @escaping (SubscriptionPlan, Bool) async throws -> SubscriptionPurchaseOutcome,
        restorePurchases: @escaping () async throws -> SubscriptionRestoreStrategy,
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
        presentationPath = router.path
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
        router.path == presentationPath && selectableContent?.selectedPlan != nil
    }

    var isRestoreDisabled: Bool {
        switch restoreSource {
        case .apple: isProcessing
        case .robokassa: false
        case .none: true
        }
    }

    private var restoreSource: SubscriptionSource? {
        switch state {
        case let content as PaywallContentState: content.selectedPlan?.source
        default: nil
        }
    }

    private var selectableContent: PaywallSuccessState? {
        switch state {
        case let content as PaywallSuccessState: content
        case let failed as PaywallOperationErrorState:
            switch failed.previousState {
            case let content as PaywallSuccessState: content
            default:
                PaywallSuccessState(
                    copying: failed,
                )
            }
        default: nil
        }
    }

    override func onInit() {
        requestCatalog()
    }

    override func onSubscriptionChanged(
        _ status: SubscriptionStatus?,
    ) {
        guard router.path == presentationPath else {
            return
        }
        switch state {
        case _ as PaywallPaymentPendingState:
            observePendingPayment()
            return
        default:
            break
        }
        guard status != nil, !isInitiallySubscribed else {
            return
        }
        switch state {
        case _ as PaywallSuccessState, _ as PaywallCatalogErrorState, _ as PaywallCatalogLoadingState:
            dismissPaywall()
        default:
            break
        }
    }

    override func onDisappear() {
        super.onDisappear()
        lastTask?.cancel()
        paymentCheckTask?.cancel()
        paymentCheckTask = nil
        paymentCheckID = nil
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
        guard router.path == presentationPath else {
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
        guard router.path == presentationPath, let content = selectableContent,
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
            content.copyWith(
                selectedType: type,
                selectedPlanID: selectedID,
            ),
        )
    }

    func onTapPlan(
        _ plan: SubscriptionPlan,
    ) {
        guard router.path == presentationPath, let content = selectableContent,
              content.displayedPlans.contains(
                  plan,
              )
        else {
            return
        }
        emit(
            content.copyWith(
                selectedPlanID: plan.id,
            ),
        )
    }

    func onToggleAutoRenewal() {
        guard router.path == presentationPath, let content = selectableContent else {
            return
        }
        emit(
            content.copyWith(
                isAutoRenewing: !content.isAutoRenewing,
            ),
        )
    }

    func onTapRetry() {
        guard router.path == presentationPath else {
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
        guard router.path == presentationPath, let source = restoreSource else {
            return
        }
        analytics.buttonTapped(
            .paywallRestoreStarted,
        )
        switch source {
        case .robokassa: openRecovery()
        case .apple: restoreAccess()
        }
    }

    func legalAttributedText(
        theme: DTheme,
        locale: Locale,
    ) -> AttributedString {
        var resource = l10n[
            .paywallAutoRenewalDescription,
        ]
        resource.locale = locale
        var text = AttributedString(
            String(
                localized: resource,
            ),
        )
        text.font = theme.typography.textSmall
        text.foregroundColor = theme.color.grayscalePlacehold
        if let range = text.range(
            of: l10n.text(
                .paywallPrivacyPolicyLabel,
            ),
        ) {
            text[
                range,
            ].foregroundColor = theme.color.primaryDefault
            text[
                range,
            ].link = container.applicationConfig.privacyPolicyUrl
        }
        if let range = text.range(
            of: l10n.text(
                .paywallTermsLabel,
            ),
        ) {
            text[
                range,
            ].foregroundColor = theme.color.primaryDefault
            text[
                range,
            ].link = container.applicationConfig.termsAndConditionsUrl
        }
        return text
    }

    func onLegalAttributedEnvironment(
        url: URL,
    ) -> OpenURLAction.Result {
        if url == container.applicationConfig.privacyPolicyUrl {
            onTapPrivacyPolicy()
            return .handled
        }
        if url == container.applicationConfig.termsAndConditionsUrl {
            onTapTerms()
            return .handled
        }
        return .systemAction
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
        guard router.path == presentationPath, let content = selectableContent, let plan = content.selectedPlan else {
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
        paymentCheckTask?.cancel()
        paymentCheckTask = nil
        paymentCheckID = nil
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
                    content.isAutoRenewing,
                )
                let outcome = initial
                guard !Task.isCancelled, router.path == presentationPath, state === purchasing else {
                    return
                }
                switch outcome {
                case .pending:
                    emit(
                        PaywallPaymentPendingState(
                            copying: content,
                        ),
                    )
                    messager.show(
                        type: .success,
                        title: l10n[
                            .subscriptionPaymentPendingDescription,
                        ],
                    )
                    observePendingPayment()
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
                    guard !Task.isCancelled, router.path == presentationPath else {
                        return
                    }
                    emit(
                        PaywallSuccessState(
                            copying: content,
                        ),
                    )
                    completePurchase()
                }
            } catch {
                guard !Task.isCancelled, router.path == presentationPath, state === purchasing else {
                    return
                }
                fail(
                    previous: content,
                    isPurchaseFailure: true,
                )
            }
        }
    }

    private func completePurchase() {
        guard router.path == presentationPath else {
            return
        }
        analytics.actionCompleted(
            .subscriptionPurchaseCompleted,
        )
        messager.show(
            type: .success,
            title: l10n[
                .paywallPurchaseSuccessTitle,
            ],
            description: l10n[
                .paywallPurchaseSuccessDescription,
            ],
        )
        dismissPaywall()
    }

    private func openRecovery() {
        coordinator.screen(
            .subscriptionRecovery,
            arguments: SubscriptionRecoveryArguments(
                onRecovered: { [weak self] in
                    self?.dismissPaywall()
                },
            ),
        )
    }

    private func restoreAccess() {
        guard router.path == presentationPath, !isProcessing, let previous = state as? PaywallContentState else {
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
                let strategy = try await restorePurchases()
                guard !Task.isCancelled, router.path == presentationPath, state === restoring else {
                    return
                }
                switch strategy {
                case .completed:
                    analytics.actionCompleted(
                        .subscriptionRestoreCompleted,
                    )
                    emit(
                        previous,
                    )
                    if subscriptionStatus != nil {
                        dismissPaywall()
                    }
                case .recoveryKeyRequired:
                    emit(
                        previous,
                    )
                    openRecovery()
                }
            } catch {
                guard !Task.isCancelled, router.path == presentationPath, state === restoring else {
                    return
                }
                fail(
                    previous: previous,
                )
            }
        }
    }

    private func observePendingPayment() {
        guard paymentCheckID == nil else {
            return
        }
        let id = UUID()
        paymentCheckID = id
        paymentCheckTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                if paymentCheckID == id {
                    paymentCheckID = nil
                    paymentCheckTask = nil
                }
            }
            for _ in 0 ..< 10 {
                do {
                    try await waitForPaymentCheck()
                    try Task.checkCancellation()
                    guard router.path == presentationPath else {
                        return
                    }
                    switch state {
                    case _ as PaywallPaymentPendingState: break
                    default: return
                    }
                    let outcome = try await checkPurchase()
                    guard !Task.isCancelled, router.path == presentationPath else {
                        return
                    }
                    switch state {
                    case let content as PaywallPaymentPendingState:
                        switch outcome {
                        case .pending: continue
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
                            completePurchase()
                        }
                    default: break
                    }
                    return
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }
    }

    private func dismissPaywall() {
        guard router.path == presentationPath else {
            return
        }
        paymentCheckTask?.cancel()
        paymentCheckTask = nil
        paymentCheckID = nil
        cancelOperationTask()
        lastTask?.cancel()
        cancelSubscriptionObservation()
        coordinator.dismissPaywall()
    }

    private func fail(
        previous: (any PaywallStateProtocol)?,
        isPurchaseFailure: Bool = false,
    ) {
        let description = l10n.text(
            isPurchaseFailure ? .subscriptionPurchaseErrorDescription : .errorUnknownDescription,
        )
        if isPurchaseFailure {
            messager.show(
                type: .error,
                title: l10n[
                    .errorUnknownTitle,
                ],
                description: l10n[
                    .subscriptionPurchaseErrorDescription,
                ],
            )
        } else {
            messager.showUnknownError(
                l10n: l10n,
            )
        }
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
            guard !Task.isCancelled, self.router.path == self.presentationPath, self.state === loading else {
                return
            }
            guard !catalog.plans.isEmpty, !catalog.tiers.isEmpty else {
                self.fail(
                    previous: nil,
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
                    isAutoRenewing: previous?.isAutoRenewing ?? true,
                ),
            )
        } onMainApiError: { _ in
            guard !Task.isCancelled, self.router.path == self.presentationPath, self.state === loading else {
                return
            }
            self.fail(
                previous: previous,
            )
        } onMainConnectionError: { _ in
            guard !Task.isCancelled, self.router.path == self.presentationPath, self.state === loading else {
                return
            }
            self.fail(
                previous: previous,
            )
        } onMainUnknownError: { _ in
            guard !Task.isCancelled, self.router.path == self.presentationPath, self.state === loading else {
                return
            }
            self.fail(
                previous: previous,
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
