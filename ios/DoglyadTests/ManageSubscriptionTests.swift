#if DEBUG
    @testable import Doglyad
    import Foundation
    import Router
    import Testing

    @MainActor
    struct ManageSubscriptionTests {
        @Test
        func previewTaskWaitsForScreenInitialization() async throws {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
            )
            let preview = Task {
                await ManageSubscriptionPreviewFactory.apply(
                    .failed,
                    to: model,
                )
            }
            await Task.yield()
            model.onAppear()
            await preview.value
            #expect(
                model.state is ManageSubscriptionErrorState,
            )
            model.onDisappear()
        }

        @Test
        func changeTypeReturnsToManagementAndRecoveryHasItsOwnScreen() async {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .manageSubscription,
                ),
            )
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: router,
            )
            model.onAppear()
            await model.lastTask?.value
            model.onTapChangeType()
            #expect(
                router.path.count == 2,
            )
            model.onDisappear()
            model.coordinator.dismissPaywall()
            model.onAppear()
            #expect(
                router.path.count == 1,
            )
            model.onTapRecovery()
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
            arguments: [SubscriptionSource.apple, .yookassa],
        )
        func currentPlanAndBenefitsAreLoadedAndProviderActionsUpdateStatus(
            source: SubscriptionSource,
        ) async throws {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: ManageSubscriptionPreviewFactory.makeStatus(
                    source: source,
                ),
            )
            model.onAppear()
            await model.lastTask?.value
            let active = try #require(
                model.state as? ManageSubscriptionActiveState,
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
                model.isManageAvailable,
            )
            model.onTapManageSubscription()
            await model.operationTask?.value
            let updated = try #require(
                model.state as? ManageSubscriptionActiveState,
            )
            switch source {
            case .yookassa:
                #expect(
                    !updated.status.isAutoRenewing && !model.isManageAvailable,
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
            let container = ManageSubscriptionPreviewFactory.makeContainer(
                code: code,
            )
            let expected = try VoiceLocalizationTestSupport.l10n(
                code: code,
            )
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
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
                model.state is ManageSubscriptionInactiveState,
            )
            #expect(
                container.l10n.text(
                    .manageSubscriptionTitle,
                ) == expected.text(
                    .manageSubscriptionTitle,
                ),
            )
            model.onTapRestore()
            await model.operationTask?.value
            let inactive = try #require(
                model.state as? ManageSubscriptionInactiveState,
            )
            #expect(
                inactive.notice == container.l10n.text(
                    .manageSubscriptionNoPurchasesDescription,
                ),
            )
            model.onDisappear()
        }

        @Test(
            arguments: ManageSubscriptionPreviewScenario.allCases,
        )
        func everyPreviewUsesAnExplicitCompleteState(
            scenario: ManageSubscriptionPreviewScenario,
        ) async {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: ManageSubscriptionPreviewFactory.status(
                    for: scenario,
                ),
            )
            model.onAppear()
            await ManageSubscriptionPreviewFactory.apply(
                scenario,
                to: model,
            )
            switch scenario {
            case .loading:
                #expect(
                    model.state is ManageSubscriptionCatalogLoadingState,
                )
            case .updating:
                #expect(
                    model.state is ManageSubscriptionRefreshLoadingState,
                )
            case .restoring:
                #expect(
                    model.state is ManageSubscriptionRestoreLoadingState,
                )
            case .managing:
                #expect(
                    model.state is ManageSubscriptionManagementLoadingState,
                )
            case .refunding:
                #expect(
                    model.state is ManageSubscriptionRefundLoadingState,
                )
            case .failed, .operationFailed:
                #expect(
                    model.state is ManageSubscriptionErrorState,
                )
            case .inactive:
                #expect(
                    model.state is ManageSubscriptionInactiveState,
                )
            case .appleBase, .applePro, .appleRenewalOff, .yooKassaBase, .yooKassaPro, .renewalOff:
                #expect(
                    model.state is ManageSubscriptionActiveState,
                )
            }
            model.onDisappear()
        }

        @Test
        func aCatalogFailureIsDistinctFromAnUnsubscribedOwner() async {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: ManageSubscriptionPreviewFactory.makeStatus(
                    source: .apple,
                ),
                isLoadingFailed: true,
            )
            model.onAppear()
            await model.lastTask?.value
            #expect(
                model.state is ManageSubscriptionErrorState,
            )
            #expect(
                model.subscriptionStatus?.type == .pro,
            )
            model.onDisappear()
        }

        @Test
        func missingTierMetadataDoesNotTurnAnActiveSubscriptionIntoAnEmptyState() async {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: ManageSubscriptionPreviewFactory.makeStatus(
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
                model.state is ManageSubscriptionErrorState && model.subscriptionStatus?.type == .pro,
            )
            model.onDisappear()
        }

        @Test
        func failedManagementRetainsTheCurrentSubscriptionSnapshot() async throws {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .menu,
                    ),
                ),
                status: ManageSubscriptionPreviewFactory.makeStatus(
                    source: .yookassa,
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
                model.state as? ManageSubscriptionActiveState,
            )
            model.onTapManageSubscription()
            await model.operationTask?.value
            let failed = try #require(
                model.state as? ManageSubscriptionErrorState,
            )
            #expect(
                (failed.previousState as? ManageSubscriptionActiveState)?.status == before.status,
            )
            model.onDisappear()
        }

        @Test
        func catalogRetryLoadsTheSameActiveSubscription() async throws {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let status = ManageSubscriptionPreviewFactory.makeStatus(
                source: .yookassa,
            )
            var requests = 0
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
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
                model.state is ManageSubscriptionErrorState,
            )
            model.onTapRetry()
            await model.lastTask?.value
            let active = try #require(
                model.state as? ManageSubscriptionActiveState,
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
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .manageSubscription,
                ),
            )
            var response: CheckedContinuation<Void, Never>?
            var calls = 0
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: ManageSubscriptionPreviewFactory.makeStatus(
                    source: .yookassa,
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
                model.state as? ManageSubscriptionActiveState,
            )
            model.onTapManageSubscription()
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
                (model.state as? ManageSubscriptionActiveState)?.status == active.status,
            )
        }

        @Test
        func leavingBeforeManagementStartsDoesNotSendTheOperation() async {
            var calls = 0
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .manageSubscription,
                ),
            )
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: ManageSubscriptionPreviewFactory.makeStatus(
                    source: .yookassa,
                ),
                manageOperation: {
                    calls += 1
                },
            )
            model.onAppear()
            await model.lastTask?.value
            model.onTapManageSubscription()
            let task = model.operationTask
            model.onTapBack()
            model.onDisappear()
            await task?.value
            #expect(
                calls == 0 && router.path.isEmpty && model.state is ManageSubscriptionActiveState,
            )
        }
    }
#endif
