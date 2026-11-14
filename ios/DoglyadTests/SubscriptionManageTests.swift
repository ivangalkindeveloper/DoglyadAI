#if DEBUG
    import Combine
    @testable import Doglyad
    import Foundation
    import Router
    import Testing

    @MainActor
    struct SubscriptionManageTests {
        init() {}

        @Test
        func previewTaskWaitsForScreenInitialization() async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
            )
            let preview = Task {
                await SubscriptionManagePreviewFactory.apply(
                    .failed,
                    to: model,
                )
            }
            await Task.yield()
            model.onAppear()
            await preview.value
            #expect(
                model.state is SubscriptionManageErrorState,
            )
            model.onDisappear()
        }

        @Test
        func changeTypeReturnsToManagementAndRecoveryHasItsOwnScreen() async {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .subscriptionManage,
                ),
            )
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: .robokassa,
                ),
            )
            model.onAppear()
            await model.lastTask?.value
            model.onTapChangeType()
            #expect(
                router.path.count == 1 && router.sheet?.type == .subscriptionChange,
            )
            let change = SubscriptionChangeViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: {
                    model.subscriptionStatus
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: SubscriptionChangeArguments(
                    source: .robokassa,
                ),
            )
            change.onTapConfirm()
            #expect(
                router.path.count == 2 && router.sheet == nil,
            )
            model.onDisappear()
            model.coordinator.dismissPaywall()
            model.onAppear()
            #expect(
                router.path.count == 1,
            )
            model.onTapRestore()
            await model.operationTask?.value
            #expect(
                router.path.count == 2,
            )
            router.pop()
            let document = RouteSheet(
                type: SheetType.webDocument,
            )
            router.push(
                route: document,
            )
            model.onTapBack()
            #expect(
                router.path.isEmpty && router.sheet?.id == document.id,
            )
            model.onDisappear()
        }

        @Test(
            arguments: [SubscriptionSource.apple, .robokassa],
        )
        func currentPlanAndBenefitsAreLoadedAndProviderActionsUpdateStatus(
            source: SubscriptionSource,
        ) async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: source,
                ),
            )
            model.onAppear()
            await model.lastTask?.value
            let active = try #require(
                model.state as? SubscriptionManageActiveState,
            )
            #expect(
                active.tier.id == .pro && active.tier.features.count == 3,
            )
            #expect(
                active.planTitle == "Pro - Месячный доступ",
            )
            #expect(
                model.expirationDescription(
                    active.status,
                )?.contains(
                    "2026",
                ) == true,
            )
            #expect(
                model.isManageAvailable == (source == .apple),
            )
            switch source {
            case .apple: model.onTapSubscriptionManage()
            case .robokassa: model.onTapDisableAutoRenewal()
            }
            await model.operationTask?.value
            let updated = try #require(
                model.state as? SubscriptionManageActiveState,
            )
            switch source {
            case .robokassa:
                #expect(
                    updated.status.isAutoRenewing && !model.isManageAvailable && model.router.sheet?.type == .subscriptionAutoRenewalDisabling,
                )
            case .apple:
                #expect(
                    updated.status.isAutoRenewing && model.isManageAvailable,
                )
            }
            #expect(
                active.status.isAutoRenewing,
            )
            model.onDisappear()
            #expect(
                model.operationTask == nil,
            )
        }

        @Test(
            arguments: ["ru", "en"],
        )
        func unsubscribedPreviewLoadsBackendTextAndExplainsRestoration(
            code: String,
        ) async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer(
                code: code,
            )
            let expected = try VoiceLocalizationTestSupport.l10n(
                code: code,
            )
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
            )
            model.onAppear()
            await model.lastTask?.value
            #expect(
                model.state is SubscriptionManageInactiveState,
            )
            #expect(
                container.l10n.text(
                    .subscriptionManageTitle,
                ) == expected.text(
                    .subscriptionManageTitle,
                ),
            )
            model.onTapRestore()
            await model.operationTask?.value
            let inactive = try #require(
                model.state as? SubscriptionManageInactiveState,
            )
            #expect(
                inactive.notice == container.l10n.text(
                    .subscriptionManageNoPurchasesDescription,
                ),
            )
            model.onDisappear()
        }

        @Test(
            arguments: SubscriptionManagePreviewScenario.allCases,
        )
        func everyPreviewUsesAnExplicitCompleteState(
            scenario: SubscriptionManagePreviewScenario,
        ) async {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: SubscriptionManagePreviewFactory.status(
                    for: scenario,
                ),
            )
            model.onAppear()
            await SubscriptionManagePreviewFactory.apply(
                scenario,
                to: model,
            )
            switch scenario {
            case .loading:
                #expect(
                    model.state is SubscriptionManageCatalogLoadingState,
                )
            case .updating:
                #expect(
                    model.state is SubscriptionManageRefreshLoadingState,
                )
            case .restoring:
                #expect(
                    model.state is SubscriptionManageRestoreLoadingState,
                )
            case .managing:
                #expect(
                    model.state is SubscriptionManageManagementLoadingState,
                )
            case .refunding:
                #expect(
                    model.state is SubscriptionManageRefundLoadingState,
                )
            case .failed, .operationFailed:
                #expect(
                    model.state is SubscriptionManageErrorState,
                )
            case .inactive:
                #expect(
                    model.state is SubscriptionManageInactiveState,
                )
            case .autoRenewalDisabledSuccess, .recoveredAccess, .purchaseCompletedSuccess, .appleBase, .applePro, .appleRenewalOff, .robokassaBase, .robokassaPro, .renewalOff:
                #expect(
                    model.state is SubscriptionManageActiveState,
                )
            }
            model.onDisappear()
        }

        @Test
        func aCatalogFailureIsDistinctFromAnUnsubscribedOwner() async {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: .apple,
                ),
                isLoadingFailed: true,
            )
            model.onAppear()
            await model.lastTask?.value
            #expect(
                model.state is SubscriptionManageErrorState,
            )
            #expect(
                model.subscriptionStatus?.type == .pro,
            )
            model.onDisappear()
        }

        @Test
        func missingTierMetadataDoesNotTurnAnActiveSubscriptionIntoAnEmptyState() async {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: .apple,
                ),
                fetchProducts: {
                    BillingProductsResponse(
                        products: [],
                        tiers: [],
                    )
                },
            )
            model.onAppear()
            await model.lastTask?.value
            #expect(
                model.state is SubscriptionManageErrorState && model.subscriptionStatus?.type == .pro,
            )
            model.onDisappear()
        }

        @Test
        func failedManagementRetainsTheCurrentSubscriptionSnapshot() async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: .apple,
                ),
                manageOperation: {
                    throw URLError(
                        .notConnectedToInternet,
                    )
                },
            )
            model.onAppear()
            await model.lastTask?.value
            let before = try #require(
                model.state as? SubscriptionManageActiveState,
            )
            model.onTapSubscriptionManage()
            await model.operationTask?.value
            let failed = try #require(
                model.state as? SubscriptionManageErrorState,
            )
            #expect(
                (failed.previousState as? SubscriptionManageActiveState)?.status == before.status,
            )
            model.onDisappear()
        }

        @Test
        func catalogRetryLoadsTheSameActiveSubscription() async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let status = SubscriptionManagePreviewFactory.makeStatus(
                source: .apple,
            )
            var requests = 0
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: status,
                fetchProducts: {
                    requests += 1
                    if requests == 1 {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    return try await SubscriptionPreviewRepository(
                        locale: container.l10n.locale,
                    ).fetchProducts()
                },
            )
            model.onAppear()
            await model.lastTask?.value
            #expect(
                model.state is SubscriptionManageErrorState,
            )
            model.onTapRetry()
            await model.lastTask?.value
            let active = try #require(
                model.state as? SubscriptionManageActiveState,
            )
            #expect(
                requests == 2 && active.status == status && active.tier.id == .pro,
            )
            model.onDisappear()
        }

        @Test(
            arguments: [false, true],
        )
        func leavingDiscardsLateManagementSuccessAndFailure(
            isFailure: Bool,
        ) async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .subscriptionManage,
                ),
            )
            var response: CheckedContinuation<Void, Never>?
            var calls = 0
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: .apple,
                ),
                manageOperation: {
                    calls += 1
                    await withCheckedContinuation {
                        response = $0
                    }
                    if isFailure {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                },
            )
            model.onAppear()
            await model.lastTask?.value
            let active = try #require(
                model.state as? SubscriptionManageActiveState,
            )
            model.onTapSubscriptionManage()
            while response == nil {
                await Task.yield()
            }
            let task = model.operationTask
            model.onTapBack()
            model.onDisappear()
            let closedState = model.state
            response?.resume()
            await task?.value
            #expect(
                calls == 1 && router.path.isEmpty && model.state === closedState,
            )
            #expect(
                (model.state as? SubscriptionManageActiveState)?.status == active.status,
            )
        }

        @Test
        func leavingBeforeManagementStartsDoesNotSendTheOperation() async {
            var calls = 0
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .subscriptionManage,
                ),
            )
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: .apple,
                ),
                manageOperation: {
                    calls += 1
                },
            )
            model.onAppear()
            await model.lastTask?.value
            model.onTapSubscriptionManage()
            let task = model.operationTask
            model.onTapBack()
            model.onDisappear()
            await task?.value
            #expect(
                calls == 0 && router.path.isEmpty && model.state is SubscriptionManageActiveState,
            )
        }
    }
#endif
