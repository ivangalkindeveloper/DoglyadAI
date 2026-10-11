import Combine
@testable import Doglyad
import Router
import Testing

@MainActor
struct SubscriptionPaywallTests {
    enum PurchaseResult: CaseIterable { case cancelled, completed, failed }

    @Test(
        arguments: PurchaseResult.allCases,
    )
    func purchaseUpdatesStateAndDismissesOnlyWhenCompleted(
        _ result: PurchaseResult,
    ) async {
        let repository = TestSubscriptionRepository()
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
                type: .subscriptionPaywall,
            ),
        )
        var refreshes = 0
        var updates = 0
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: { updates += 1 },
            onRefresh: { refreshes += 1 },
        )

        model.onTapPlan(
            repository.plan,
        )
        model.onTapPlan(
            repository.plan,
        )
        await waitUntilIdle(
            model,
        )

        #expect(
            repository.purchaseCount == 1,
        )
        #expect(
            !model.isLoading,
        )
        switch result {
        case .cancelled:
            #expect(
                root.status == nil,
            )
            #expect(
                !router.path.isEmpty,
            )
            #expect(
                model.errorDescription == nil,
            )
            #expect(
                updates == 0,
            )
            #expect(
                refreshes == 0,
            )
        case .completed:
            #expect(
                root.status?.type == .pro,
            )
            #expect(
                router.path.isEmpty,
            )
            #expect(
                model.errorDescription == nil,
            )
            #expect(
                updates == 1,
            )
            #expect(
                refreshes == 1,
            )
        case .failed:
            #expect(
                root.status == nil,
            )
            #expect(
                !router.path.isEmpty,
            )
            #expect(
                model.errorDescription == container.l10n.text(
                    .errorUnknownDescription,
                ),
            )
            #expect(
                updates == 0,
            )
            #expect(
                refreshes == 0,
            )
        }
    }

    @Test(
        arguments: [true, false],
    )
    func loadingRetriesAndRestorationUpdatesSharedState(
        hasActiveSubscription: Bool,
    ) async {
        let repository = TestSubscriptionRepository()
        repository.failLoading = true
        repository.hasRestorableSubscription = hasActiveSubscription
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
                type: .subscriptionPaywall,
            ),
        )
        var refreshes = 0
        let model = makeModel(
            container: container,
            root: root,
            router: router,
            onUpdate: {},
            onRefresh: { refreshes += 1 },
        )

        model.onAppear()
        await waitUntilIdle(
            model,
        )
        #expect(
            model.plans.isEmpty,
        )
        #expect(
            model.errorDescription == container.l10n.text(
                .subscriptionOfferingsUnavailableDescription,
            ),
        )

        repository.failLoading = false
        model.onTapRetry()
        await waitUntilIdle(
            model,
        )
        #expect(
            model.plans.map(
                \.id,
            ) == [repository.plan.id],
        )
        #expect(
            model.errorDescription == nil,
        )

        model.onTapRestore()
        await waitUntilIdle(
            model,
        )
        #expect(
            (root.status != nil) == hasActiveSubscription,
        )
        #expect(
            model.isSubscriptionActive == hasActiveSubscription,
        )
        #expect(
            router.path.isEmpty == hasActiveSubscription,
        )
        #expect(
            refreshes == 1,
        )
        #expect(
            repository.restoreCount == 1,
        )
    }

    private func waitUntilIdle(
        _ model: SubscriptionPaywallViewModel,
    ) async {
        for await loading in model.$isLoading.values {
            if !loading { return }
        }
    }

    private func makeModel(
        container: DependencyContainer,
        root: SubscriptionRootViewModel,
        router: DRouter,
        onUpdate: @escaping () -> Void,
        onRefresh: @escaping () async -> Void,
    ) -> SubscriptionPaywallViewModel {
        SubscriptionPaywallViewModel(
            container: container,
            router: router,
            getSubscriptionStatus: { root.status },
            observeSubscriptionStatus: { root.observeStatus(
                $0,
            ) },
            onSubscriptionStatusUpdated: { root.update(
                status: $0,
            )
            onUpdate()
            },
            getNeuralModelSettings: { root.neuralModelSettings },
            onRequestCountIncremented: {},
            arguments: SubscriptionPaywallArguments(),
            onRefreshStatus: onRefresh,
        )
    }

    private func makeContainer(
        repository: SubscriptionRepositoryProtocol,
    ) -> DependencyContainer {
        let base = DependencyContainer.previewable
        return DependencyContainer(
            analytics: base.analytics,
            environment: base.environment,
            connectionManager: base.connectionManager,
            permissionManager: base.permissionManager,
            mockFactory: base.mockFactory,
            sharedRepository: base.sharedRepository,
            userSettingsRepository: base.userSettingsRepository,
            ultrasoundModelRepository: base.ultrasoundModelRepository,
            ultrasoundReportRepository: base.ultrasoundReportRepository,
            ultrasoundDraftRepository: base.ultrasoundDraftRepository,
            templateRepository: base.templateRepository,
            subscriptionRepository: repository,
            applicationConfig: base.applicationConfig,
            language: base.language,
            l10n: base.l10n,
            usExaminationTypeGroups: base.usExaminationTypeGroups,
            usExaminationTypesById: base.usExaminationTypesById,
            usExaminationTypeDefault: base.usExaminationTypeDefault,
            usExaminationNeuralModels: base.usExaminationNeuralModels,
            usExaminationNeuralModelsById: base.usExaminationNeuralModelsById,
            usExaminationNeuralModelDefault: base.usExaminationNeuralModelDefault,
            examinationNeuralModelFactory: base.examinationNeuralModelFactory,
            initialSubscriptionStatus: nil,
            initialRoute: base.initialRoute,
            version: base.version,
        )
    }
}

@MainActor
private final class TestSubscriptionRepository: SubscriptionRepositoryProtocol {
    var purchaseResult = SubscriptionPaywallTests.PurchaseResult.cancelled
    var purchaseCount = 0
    var restoreCount = 0
    var failLoading = false
    var hasRestorableSubscription = true
    let plan = SubscriptionPlan(
        id: "monthly",
        productId: "test.monthly",
        kind: .monthly,
        price: "$1.00",
    )
    let status = SubscriptionStatus(
        type: .pro,
        entitlement: SubscriptionEntitlement(
            requestCountPerDay: 20,
            formCompletionViaMicrophone: .available,
            sendingReportByEmail: .available,
            neuralModelSettings: .available,
        ),
        availableCountPerDay: 20,
    )

    func configure() {}
    func fetchPlans() async throws -> [SubscriptionPlan] {
        if failLoading { throw SubscriptionError.offeringsUnavailable }
        return [plan]
    }

    func purchase(
        plan _: SubscriptionPlan,
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionPurchaseOutcome {
        purchaseCount += 1
        switch purchaseResult {
        case .cancelled: return .cancelled
        case .completed: return .completed(
                status,
            )
        case .failed: throw SubscriptionError.offeringsUnavailable
        }
    }

    func restorePurchases(
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        restoreCount += 1
        return hasRestorableSubscription ? status : nil
    }

    func cachedStatus(
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? { nil }
    func fetchStatus(
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? { status }
    func incrementRequestCount(
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? { status }
    func manageSubscription() async throws {}
    func requestRefund() async throws {}
}
