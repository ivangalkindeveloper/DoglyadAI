import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct PaywallTests {
    init() {}

    enum PurchaseResult: CaseIterable { case cancelled, completed, failed, pending }

    @Test(
        arguments: [ScreenType.onBoarding, .scan, .subscriptionManage, .reportDetail],
    )
    func confirmedPurchaseReturnsToItsOrigin(
        origin: ScreenType,
    ) async {
        let repository = SubscriptionTestRepository()
        repository.purchaseResult = .completed
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: origin == .onBoarding ? .paywall : .scan,
            ),
        )
        if origin == .subscriptionManage || origin == .reportDetail {
            router.push(
                route: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: origin,
                ),
            )
        }
        let originDepth = router.path.count
        if origin != .onBoarding {
            router.push(
                route: RouteScreen(
                    type: .paywall,
                ),
            )
        }
        let messager = DMessager()
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
            messager: messager,
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapContinue()
        await waitUntilIdle(
            model,
        )
        #expect(
            router.path.count == originDepth && root.status != nil && repository.purchaseCount == 1,
        )
        #expect(
            messager.message.map {
                String(
                    localized: $0.title,
                )
            } == container.l10n.text(
                .paywallPurchaseSuccessTitle,
            ),
        )
        #expect(
            messager.message?.description.map {
                String(
                    localized: $0,
                )
            } == container.l10n.text(
                .paywallPurchaseSuccessDescription,
            ),
        )
        model.onDisappear()
    }

    @Test(
        arguments: [SubscriptionSource.apple, .robokassa],
    )
    func recoveryWaitsForTheCatalogAndUsesItsProvider(
        source: SubscriptionSource,
    ) async {
        let backend = SubscriptionTestBackendRepository()
        let apple = SubscriptionTestRepository(
            backend: backend,
            source: .apple,
        )
        let robokassa = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        var storefrontReads = 0
        let container = makeSubscriptionTestContainer(
            backend: backend,
            storeKit: apple,
            robokassa: robokassa,
            getStorefrontCountryCode: {
                storefrontReads += 1
                return source == .robokassa ? "RUS" : "USA"
            },
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        let loading = model.state
        #expect(
            model.isProcessing && model.isRestoreDisabled,
        )
        model.onTapRestore()
        #expect(
            router.path.count == 1 && model.state === loading && storefrontReads == 0,
        )
        #expect(
            apple.restoreCount == 0 && robokassa.restoreCount == 0,
        )

        model.onAppear()
        await waitUntilIdle(
            model,
        )
        #expect(
            !model.isRestoreDisabled && storefrontReads == 1,
        )
        model.onTapRestore()
        await model.operationTask?.value
        #expect(
            robokassa.restoreCount == 0,
        )
        switch source {
        case .robokassa:
            #expect(
                router.path.count == 2 && apple.restoreCount == 0 && storefrontReads == 1,
            )
        case .apple:
            #expect(
                router.path.isEmpty && apple.restoreCount == 1 && storefrontReads == 2,
            )
        }
        model.onDisappear()
    }

    @Test(
        arguments: [SubscriptionSource.apple, .robokassa],
    )
    func recoveryAvailabilityDuringPurchaseDependsOnTheProvider(
        source: SubscriptionSource,
    ) async throws {
        let repository = SubscriptionTestRepository(
            source: source,
        )
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        let content = try #require(
            model.state as? PaywallContentState,
        )
        let purchasing = PaywallPurchaseLoadingState(
            content: content,
            plan: repository.plan,
        )
        model.emit(
            purchasing,
        )
        #expect(
            model.isRestoreDisabled == (source == .apple),
        )
        model.onTapRestore()
        #expect(
            router.path.count == (source == .robokassa ? 2 : 1),
        )
        #expect(
            model.state === purchasing && repository.restoreCount == 0,
        )
        model.onDisappear()
    }

    @Test
    func catalogFailureDoesNotRouteRecoveryOrQueryStorefrontAgain() async {
        let repository = SubscriptionTestRepository(
            source: .robokassa,
        )
        repository.isLoadingFailed = true
        var storefrontReads = 0
        let container = makeSubscriptionTestContainer(
            backend: repository.backend,
            storeKit: SubscriptionTestRepository(
                backend: repository.backend,
            ),
            robokassa: repository,
            getStorefrontCountryCode: {
                storefrontReads += 1
                return "RUS"
            },
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        let failed = model.state
        #expect(
            failed is PaywallCatalogErrorState && model.isRestoreDisabled,
        )
        model.onTapRestore()
        #expect(
            router.path.count == 1 && model.state === failed && storefrontReads == 1,
        )
        #expect(
            repository.restoreCount == 0,
        )
        model.onDisappear()
    }

    @Test
    func autoRenewalDefaultsToEnabledAndPreservesTheChoiceThroughPurchaseCancellation() async {
        let repository = SubscriptionTestRepository(
            source: .robokassa,
        )
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        #expect(
            (model.state as? PaywallContentState)?.isAutoRenewing == true,
        )
        model.onToggleAutoRenewal()
        #expect(
            (model.state as? PaywallContentState)?.isAutoRenewing == false,
        )
        model.onTapContinue()
        await waitUntilIdle(
            model,
        )
        #expect(
            repository.purchasedIsAutoRenewing == false,
        )
        #expect(
            (model.state as? PaywallContentState)?.isAutoRenewing == false,
        )
        model.onToggleAutoRenewal()
        #expect(
            (model.state as? PaywallContentState)?.isAutoRenewing == true,
        )
        model.onDisappear()
    }

    @Test
    func closeIgnoresSubscriptionUpdatesBeforeTheDisappearEvent() async {
        let repository = SubscriptionTestRepository()
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapClose()
        router.push(
            route: RouteScreen(
                type: .menu,
            ),
        )
        root.update(
            status: repository.status,
        )
        model.onTapClose()
        model.onTapContinue()
        model.onTapRestore()
        #expect(
            router.path.count == 1,
        )
        #expect(
            !model.isContinueEnabled && model.operationTask == nil,
        )
        model.onDisappear()
    }

    @Test
    func externalRestorationPreservesThePresentedDocument() async {
        let repository = SubscriptionTestRepository()
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        let document = RouteSheet(
            type: SheetType.webDocument,
        )
        router.push(
            route: document,
        )
        root.update(
            status: repository.status,
        )
        #expect(
            router.path.isEmpty && router.sheet?.id == document.id,
        )
        model.onDisappear()
    }

    @Test
    func hiddenPaywallIgnoresSubscriptionChangesAndReobservesOnReturn() async {
        let repository = SubscriptionTestRepository()
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        router.pop()
        model.onDisappear()
        router.push(
            route: RouteScreen(
                type: .menu,
            ),
        )
        root.update(
            status: repository.status,
        )
        #expect(
            router.path.count == 1 && model.subscriptionStatus == nil,
        )
        router.pop()
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        model.onAppear()
        #expect(
            router.path.isEmpty && model.subscriptionStatus?.type == .pro,
        )
        model.onDisappear()
    }

    @Test
    func selectionIsLocalAndContinuePurchasesOnlyTheSelectedPlan() async {
        let repository = SubscriptionTestRepository()
        let proMonthly = makePlan(
            type: .pro,
            period: .monthly,
        )
        let proAnnual = makePlan(
            type: .pro,
            period: .annual,
        )
        let baseAnnual = makePlan(
            type: .base,
            period: .annual,
        )
        repository.availablePlans = [proMonthly, makePlan(
            type: .base,
            period: .weekly,
        ), proAnnual, baseAnnual]
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedType == .pro && (model.state as? PaywallContentState)?.selectedPlan == proAnnual,
        )
        #expect(
            (model.state as? PaywallContentState)?.displayedPlans == [proAnnual, proMonthly],
        )
        model.onTapPlan(
            proMonthly,
        )
        model.onSelectType(
            .pro,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedPlan == proMonthly && repository.purchaseCount == 0,
        )
        model.onSelectType(
            .base,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedPlan == baseAnnual && (model.state as? PaywallContentState)?.selectedTier?.features.count == 1,
        )
        model.onTapPlan(
            proMonthly,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedPlan == baseAnnual && repository.purchaseCount == 0,
        )
        model.onSelectType(
            .pro,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedTier?.features.count == 3,
        )
        model.onTapPlan(
            proMonthly,
        )
        model.onTapContinue()
        model.onTapContinue()
        await waitUntilIdle(
            model,
        )
        #expect(
            repository.purchaseCount == 1 && repository.purchasedPlan == proMonthly,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedPlan == proMonthly,
        )
    }

    @Test
    func unavailableTierAndEmptyCatalogCannotStartAPurchase() async {
        let repository = SubscriptionTestRepository()
        let baseAnnual = makePlan(
            type: .base,
            period: .annual,
        )
        repository.availablePlans = [baseAnnual]
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedType == .base && (model.state as? PaywallContentState)?.selectedPlan == baseAnnual,
        )
        model.onSelectType(
            .pro,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedPlan == baseAnnual && model.isContinueEnabled && repository.purchaseCount == 0,
        )
        model.onSelectType(
            .base,
        )
        #expect(
            (model.state as? PaywallContentState)?.selectedPlan == baseAnnual,
        )
        repository.availablePlans = []
        model.onTapRetry()
        await waitUntilIdle(
            model,
        )
        model.onTapContinue()
        #expect(
            (model.state as? PaywallContentState)?.selectedPlan == nil && !model.isContinueEnabled && repository.purchaseCount == 0,
        )
    }

    @Test
    func paywallOwnsPlansAndResolvesTheProviderAgainOnRetry() async {
        let backend = SubscriptionTestBackendRepository()
        let apple = SubscriptionTestRepository(
            backend: backend,
        )
        let robokassa = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        var countryCode = "USA"
        var reads = 0
        let container = makeSubscriptionTestContainer(
            backend: backend,
            storeKit: apple,
            robokassa: robokassa,
            getStorefrontCountryCode: {
                reads += 1
                return countryCode
            },
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        #expect(
            reads == 0,
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        #expect(
            (model.state as? PaywallContentState)?.plans == [apple.plan] && reads == 1,
        )
        countryCode = "RUS"
        #expect(
            (model.state as? PaywallContentState)?.plans == [apple.plan] && reads == 1,
        )
        model.onTapRetry()
        await waitUntilIdle(
            model,
        )
        #expect(
            (model.state as? PaywallContentState)?.plans == [robokassa.plan] && reads == 2,
        )
        #expect(
            root.status == nil,
        )
    }

    @Test
    func refreshingStatusReturnsAfterPublishingServerStatus() async {
        let repository = SubscriptionTestRepository()
        let root = SubscriptionRootViewModel(
            container: makeContainer(
                repository: repository,
            ),
        )
        #expect(
            root.status == nil,
        )
        repository.backend.isAccessAvailable = true
        await root.refreshStatus()
        #expect(
            root.status == repository.status,
        )
    }

    @Test
    func rootStartsObservationOnlyOnceFromLifecycle() async {
        let repository = SubscriptionTestRepository()
        let root = SubscriptionRootViewModel(
            container: makeContainer(
                repository: repository,
            ),
        )
        await Task.yield()
        #expect(
            repository.observationCount == 0,
        )
        root.onInit()
        root.onInit()
        for _ in 0 ..< 100 {
            if repository.observationCount == 1 {
                break
            }
            await Task.yield()
        }
        #expect(
            repository.observationCount == 1,
        )
        repository.changes.send(
            .success(
                (),
            ),
        )
        for _ in 0 ..< 100 {
            if root.status != nil {
                break
            }
            await Task.yield()
        }
        #expect(
            root.status?.type == .pro,
        )
    }

    @Test(
        arguments: PurchaseResult.allCases,
    )
    func purchaseUpdatesStateAndDismissesOnlyWhenCompleted(
        _ result: PurchaseResult,
    ) async {
        let repository = SubscriptionTestRepository()
        repository.purchaseResult = result
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        var updates = 0
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {
                updates += 1
            },
        )

        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapPlan(
            repository.plan,
        )
        model.onTapContinue()
        model.onTapPlan(
            repository.plan,
        )
        model.onTapContinue()
        if result == .pending {
            await waitUntilIdle(
                model,
            )
        } else {
            await waitUntilIdle(
                model,
            )
        }

        #expect(
            repository.purchaseCount == 1,
        )
        if result != .pending {
            switch model.state {
            case _ as PaywallCatalogLoadingState, _ as PaywallPurchaseLoadingState, _ as PaywallRestoreLoadingState:
                Issue.record(
                    "Purchase must leave its processing state",
                )
            default: break
            }
        }

        switch result {
        case .cancelled:
            #expect(
                root.status == nil,
            )
            #expect(
                !router.path.isEmpty,
            )
            switch model.state {
            case _ as PaywallContentState: break
            default:
                Issue.record(
                    "A completed or cancelled purchase must retain loaded plans",
                )
            }
            #expect(
                updates == 0,
            )
        case .completed:
            #expect(
                root.status?.type == .pro,
            )
            #expect(
                router.path.isEmpty,
            )
            switch model.state {
            case _ as PaywallContentState: break
            default:
                Issue.record(
                    "A completed or cancelled purchase must retain loaded plans",
                )
            }
            #expect(
                updates == 1,
            )
        case .pending:
            #expect(
                root.status == nil,
            )
            #expect(
                !router.path.isEmpty,
            )
            #expect(
                updates == 0,
            )
            switch model.state {
            case _ as PaywallPaymentPendingState: break
            default:
                Issue.record(
                    "Pending payment must await a verified backend result",
                )
            }
        case .failed:
            #expect(
                root.status == nil,
            )
            #expect(
                !router.path.isEmpty,
            )
            switch model.state {
            case let state as PaywallOperationErrorState:
                #expect(
                    state.errorDescription == container.l10n.text(
                        .subscriptionPurchaseErrorDescription,
                    ),
                )
                #expect(
                    (model.state as? PaywallContentState)?.plans.map(
                        \.id,
                    ) == [repository.plan.id],
                )
            default:
                Issue.record(
                    "Expected a purchase failure with the loaded plans",
                )
            }
            #expect(
                updates == 0,
            )
        }
        model.onDisappear()
    }

    @Test(
        arguments: [true, false],
    )
    func loadingRetriesAndRestorationUpdatesSharedState(
        isSubscriptionActive: Bool,
    ) async {
        let repository = SubscriptionTestRepository()
        repository.isLoadingFailed = true
        repository.isRestorableSubscriptionAvailable = isSubscriptionActive
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let messager = DMessager()
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
            messager: messager,
        )

        model.onAppear()
        await waitUntilIdle(
            model,
        )
        switch model.state {
        case let state as PaywallCatalogErrorState:
            #expect(
                state.errorDescription == container.l10n.text(
                    .errorUnknownDescription,
                ),
            )
        default:
            Issue.record(
                "Expected an offerings load failure",
            )
        }

        #expect(
            messager.message?.description.map {
                String(
                    localized: $0,
                )
            } == container.l10n.text(
                .errorUnknownDescription,
            ),
        )
        repository.isLoadingFailed = false
        model.onTapRetry()
        await waitUntilIdle(
            model,
        )
        switch model.state {
        case _ as PaywallContentState:
            #expect(
                (model.state as? PaywallContentState)?.plans.map(
                    \.id,
                ) == [repository.plan.id],
            )
        default:
            Issue.record(
                "Retry must publish the loaded plans",
            )
        }

        model.onTapRestore()
        await waitUntilIdle(
            model,
        )
        #expect(
            (root.status != nil) == isSubscriptionActive,
        )
        #expect(
            (model.subscriptionStatus != nil) == isSubscriptionActive,
        )
        #expect(
            router.path.isEmpty == isSubscriptionActive,
        )
        #expect(
            repository.restoreCount == 1,
        )
    }

    @Test
    func pendingPurchaseCompletesFromVerifiedRepositoryUpdate() async {
        let repository = SubscriptionTestRepository()
        repository.purchaseResult = .pending
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapPlan(
            repository.plan,
        )
        model.onTapContinue()
        await waitUntilPurchaseStarted(
            repository,
        )
        await waitUntilIdle(
            model,
        )
        switch model.state {
        case _ as PaywallPaymentPendingState: break
        default:
            Issue.record(
                "Expected a pending purchase",
            )
        }
        #expect(
            repository.observationCount == 1,
        )
        repository.changes.send(
            .success(
                (),
            ),
        )
        for _ in 0 ..< 100 {
            if router.path.isEmpty {
                break
            }
            try? await Task.sleep(
                for: .milliseconds(
                    10,
                ),
            )
        }

        #expect(
            root.status?.type == .pro,
        )
        #expect(
            router.path.isEmpty,
        )
        model.onDisappear()
    }

    @Test
    func pendingPurchaseDoesNotCompleteFromUnrelatedBaseAccess() async {
        let repository = SubscriptionTestRepository()
        repository.purchaseResult = .pending
        repository.status = SubscriptionStatus(
            planId: "monthly",
            type: .base,
            entitlement: repository.status.entitlement,
            availableCountPerDay: 15,
            source: .robokassa,
        )
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapPlan(
            repository.plan,
        )
        model.onTapContinue()
        await waitUntilPurchaseStarted(
            repository,
        )
        repository.backend.isAccessAvailable = true
        await root.refreshStatus()
        try? await Task.sleep(
            for: .milliseconds(
                40,
            ),
        )
        model.onToggleAutoRenewal()
        #expect(
            model.state is PaywallPaymentPendingState && !model.isProcessing && repository.restoreCount == 0,
        )

        #expect(
            root.status?.type == .base,
        )
        #expect(
            !router.path.isEmpty,
        )
        model.onDisappear()
    }

    @Test(
        arguments: [false, true],
    )
    func restoredIdentityClosesPaywallOnlyForPreviouslyUnsubscribedOwner(
        isAlreadySubscribed: Bool,
    ) async {
        let repository = SubscriptionTestRepository()
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        if isAlreadySubscribed {
            root.update(
                status: repository.status,
            )
        }
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        let refreshed = SubscriptionStatus(
            planId: "monthly",
            type: .pro,
            entitlement: repository.status.entitlement,
            availableCountPerDay: 19,
        )
        root.update(
            status: refreshed,
        )
        #expect(
            router.path.isEmpty == !isAlreadySubscribed,
        )
    }

    @Test
    func pendingRobokassaPaymentClosesOnlyAfterItsExactConfirmation() async {
        let repository = SubscriptionTestRepository(
            source: .robokassa,
        )
        repository.purchaseResult = .pending
        let id = UUID()
        repository.preparedPaymentID = id
        repository.backend.status.source = .robokassa
        repository.backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: repository.plan.id,
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let messager = DMessager()
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
            messager: messager,
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapPlan(
            repository.plan,
        )
        model.onTapContinue()
        await waitUntilIdle(
            model,
        )
        #expect(
            model.state is PaywallPaymentPendingState && !model.isProcessing,
        )
        #expect(
            !router.path.isEmpty && root.status == nil,
        )
        #expect(
            messager.message.map {
                String(
                    localized: $0.title,
                )
            } != container.l10n.text(
                .paywallPurchaseSuccessTitle,
            ),
        )
        repository.backend.isAccessAvailable = true
        repository.backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: repository.plan.id,
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        for _ in 0 ..< 100 {
            if router.path.isEmpty {
                break
            }
            try? await Task.sleep(
                for: .milliseconds(
                    10,
                ),
            )
        }
        #expect(
            root.status?.source == .robokassa && router.path.isEmpty,
        )
        #expect(
            repository.purchaseCount == 1,
        )
        #expect(
            messager.message.map {
                String(
                    localized: $0.title,
                )
            } == container.l10n.text(
                .paywallPurchaseSuccessTitle,
            ),
        )
        #expect(
            messager.message?.description.map {
                String(
                    localized: $0,
                )
            } == container.l10n.text(
                .paywallPurchaseSuccessDescription,
            ),
        )
        model.onDisappear()
    }

    @Test
    func retryingTheSamePendingPaymentCannotPurchaseAnotherPeriod() async throws {
        let repository = SubscriptionTestRepository(
            source: .robokassa,
        )
        repository.purchaseResult = .pending
        let id = UUID()
        repository.preparedPaymentID = id
        repository.backend.status.source = .robokassa
        repository.backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: repository.plan.id,
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let root = SubscriptionRootViewModel(
            container: makeContainer(
                repository: repository,
            ),
        )
        _ = try await root.purchase(
            plan: repository.plan,
        )
        _ = try await root.purchase(
            plan: repository.plan,
        )
        #expect(
            repository.purchaseCount == 1,
        )
        repository.backend.isAccessAvailable = true
        repository.backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: repository.plan.id,
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let outcome = try await root.purchase(
            plan: repository.plan,
        )
        switch outcome {
        case let .completed(
            status,
        ):
            #expect(
                status?.planId == repository.plan.id,
            )
        case .pending, .cancelled:
            Issue.record(
                "A retry must recover the confirmed original payment",
            )
        }
        #expect(
            repository.purchaseCount == 1,
        )
        #expect(
            repository.backend.checkedPayments == [id, id],
        )
    }

    @Test
    func canceledExternalPaymentReloadsPlansInsteadOfRemainingPending() async {
        let repository = SubscriptionTestRepository(
            source: .robokassa,
        )
        repository.purchaseResult = .pending
        let id = UUID()
        repository.preparedPaymentID = id
        repository.backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: "monthly",
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapPlan(
            repository.plan,
        )
        model.onTapContinue()
        await waitUntilPurchaseStarted(
            repository,
        )
        repository.backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: "monthly",
            status: .canceled,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        await waitUntilIdle(
            model,
        )
        switch model.state {
        case _ as PaywallContentState: break
        default:
            Issue.record(
                "Canceled checkout must return to the available plans",
            )
        }
        #expect(
            root.status == nil && (model.state as? PaywallContentState)?.plans == [repository.plan],
        )
        model.onDisappear()
    }

    @Test(
        arguments: [false, true],
    )
    func copyingSelectionPreservesItsConcretePhaseAndOriginalSnapshot(
        isPending: Bool,
    ) async throws {
        let repository = SubscriptionTestRepository(
            source: .robokassa,
        )
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        let loaded = try #require(
            model.state as? PaywallSuccessState,
        )
        let original: PaywallSuccessState = isPending ? PaywallPaymentPendingState(
            copying: loaded,
        ) : loaded
        model.emit(
            original,
        )
        model.onToggleAutoRenewal()
        let updated = try #require(
            model.state as? PaywallSuccessState,
        )
        #expect(
            updated !== original && type(
                of: updated,
            ) == type(
                of: original,
            ),
        )
        #expect(
            original.isAutoRenewing && !updated.isAutoRenewing,
        )
        #expect(
            updated.plans == original.plans && updated.tiers == original.tiers && updated.selectedPlan == original.selectedPlan,
        )
        model.onDisappear()
    }

    @Test
    func snapshotsRetainSelectionAndServerMetadataAcrossPurchasePhases() async throws {
        let repository = SubscriptionTestRepository()
        repository.tiers = [SubscriptionTier(
            id: .pro,
            title: "Custom tier",
            features: ["Server benefit"],
        )]
        let annual = makePlan(
            type: .pro,
            period: .annual,
        )
        repository.availablePlans = [annual, repository.plan]
        repository.purchaseResult = .failed
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        let original = try #require(
            model.state as? PaywallSuccessState,
        )
        model.onTapPlan(
            repository.plan,
        )
        let selected = try #require(
            model.state as? PaywallSuccessState,
        )
        #expect(
            original.selectedPlan == annual,
        )
        #expect(
            selected.selectedPlan == repository.plan,
        )
        #expect(
            selected.selectedTier?.title == "Custom tier" && selected.selectedTier?.features == ["Server benefit"],
        )
        model.onTapContinue()
        let purchasing = try #require(
            model.state as? PaywallPurchaseLoadingState,
        )
        #expect(
            purchasing.selectedPlan == repository.plan && purchasing.plans == original.plans,
        )
        model.onTapPlan(
            annual,
        )
        #expect(
            model.state === purchasing && !model.isContinueEnabled,
        )
        await waitUntilIdle(
            model,
        )
        let failed = try #require(
            model.state as? PaywallOperationErrorState,
        )
        #expect(
            failed.previousState === selected && failed.selectedPlan == repository.plan,
        )
        repository.purchaseResult = .cancelled
        model.onTapContinue()
        await waitUntilIdle(
            model,
        )
        let cancelled = try #require(
            model.state as? PaywallSuccessState,
        )
        #expect(
            cancelled.selectedPlan == repository.plan && original.selectedPlan == annual,
        )
        model.onDisappear()
    }

    @Test
    func restoreFailureRetainsSelectionAndDisappearanceCancelsTheOperation() async throws {
        let repository = SubscriptionTestRepository()
        repository.availablePlans = [makePlan(
            type: .pro,
            period: .annual,
        ), repository.plan]
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        model.onAppear()
        await waitUntilIdle(
            model,
        )
        model.onTapPlan(
            repository.plan,
        )
        let selected = try #require(
            model.state as? PaywallSuccessState,
        )
        repository.onRestore = {
            throw SubscriptionError.offeringsUnavailable
        }
        model.onTapRestore()
        await waitUntilIdle(
            model,
        )
        let failed = try #require(
            model.state as? PaywallOperationErrorState,
        )
        #expect(
            failed.previousState === selected && failed.selectedPlan == repository.plan,
        )
        repository.onRestore = {
            try await Task.sleep(
                for: .seconds(
                    60,
                ),
            )
        }
        model.onTapRestore()
        #expect(
            model.state is PaywallRestoreLoadingState,
        )
        let operation = model.operationTask
        model.onDisappear()
        await operation?.value
        #expect(
            model.state === failed && model.operationTask == nil,
        )
        model.onAppear()
        repository.onRestore = nil
        model.onTapRetry()
        await waitUntilIdle(
            model,
        )
        let retried = try #require(
            model.state as? PaywallSuccessState,
        )
        #expect(
            retried.selectedPlan == repository.plan,
        )
        model.onDisappear()
    }

    @Test(
        arguments: [false, true],
    )
    func cancelledCatalogDiscardsLateSuccessAndFailure(
        isFailure: Bool,
    ) async {
        let repository = SubscriptionTestRepository()
        repository.isLoadingFailed = isFailure
        var response: CheckedContinuation<Void, Never>?
        repository.onFetchCatalog = {
            await withCheckedContinuation {
                response = $0
            }
        }
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let model = makeModel(
            container: container,
            root: root,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            onUpdate: {},
        )
        model.onAppear()
        while response == nil {
            await Task.yield()
        }
        let loading = model.state
        let task = model.lastTask
        task?.cancel()
        response?.resume()
        await task?.value
        #expect(
            model.state === loading && !model.isContinueEnabled,
        )
        model.onDisappear()
    }

    @Test
    func closeIgnoresALateCatalogResponse() async throws {
        let repository = SubscriptionTestRepository()
        var response: CheckedContinuation<Void, Never>?
        repository.onFetchCatalog = {
            await withCheckedContinuation {
                response = $0
            }
        }
        let container = makeContainer(
            repository: repository,
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .paywall,
            ),
        )
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
        )
        model.onAppear()
        while response == nil {
            await Task.yield()
        }
        let loading = model.state
        model.onTapClose()
        router.push(
            route: RouteScreen(
                type: .menu,
            ),
        )
        response?.resume()
        await model.lastTask?.value
        #expect(
            model.state === loading && router.path.count == 1,
        )
        #expect(
            !model.isContinueEnabled,
        )
        model.onDisappear()
    }

    private func makePlan(
        type: SubscriptionType,
        period: SubscriptionPeriod,
    ) -> SubscriptionPlan {
        SubscriptionPlan(
            id: "\(type.rawValue)-\(period.rawValue)",
            source: .apple,
            type: type,
            period: period,
            title: "Test subscription",
            price: "$9.99",
        )
    }

    private func waitUntilPurchaseStarted(
        _ repository: SubscriptionTestRepository,
    ) async {
        for _ in 0 ..< 1000 {
            if repository.purchaseCount > 0 {
                break
            }
            await Task.yield()
        }
        try? await Task.sleep(
            for: .milliseconds(
                25,
            ),
        )
    }

    private func waitUntilIdle(
        _ model: PaywallViewModel,
    ) async {
        for _ in 0 ..< 500 {
            if !model.isProcessing {
                return
            }
            try? await Task.sleep(
                for: .milliseconds(
                    10,
                ),
            )
        }
        Issue.record(
            "Expected the checkout operation to reach a terminal state within five seconds",
        )
    }

    private func makeModel(
        container: DependencyContainer,
        root: SubscriptionRootViewModel,
        router: DRouter,
        onUpdate: @escaping () -> Void,
        messager: DMessager? = nil,
    ) -> PaywallViewModel {
        root.onInit()
        return PaywallViewModel(
            messager: messager ?? DMessager(),
            container: container,
            router: router,
            getSubscriptionStatus: {
                root.status
            },
            observeSubscriptionStatus: {
                root.observeStatus(
                    $0,
                )
            },
            onSubscriptionStatusUpdated: {
                root.update(
                    status: $0,
                )
                onUpdate()
            },
            getSettingsAI: {
                root.resolveSettingsAI()
            },
            onRefreshSubscriptionStatus: {},
            arguments: PaywallArguments(),
            purchase: {
                try await root.purchase(
                    plan: $0,
                    isAutoRenewing: $1,
                )
            },
            restorePurchases: {
                try await root.restorePurchases()
            },
            checkPurchase: {
                try await root.checkPurchase()
            },
            waitForPaymentCheck: {
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            },
        )
    }

    private func makeContainer(
        repository: SubscriptionTestRepository,
    ) -> DependencyContainer {
        makeSubscriptionTestContainer(
            backend: repository.backend,
            storeKit: repository,
            robokassa: repository,
        )
    }
}
