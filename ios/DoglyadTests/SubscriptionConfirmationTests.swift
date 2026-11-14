#if DEBUG
    import Combine
    @testable import Doglyad
    import DoglyadUI
    import Foundation
    import Router
    import Testing

    @MainActor
    struct SubscriptionConfirmationTests {
        init() {}

        @Test(
            arguments: [SubscriptionSource.apple, .robokassa],
        )
        func changingPlanRequiresConfirmationAndUsesProviderText(
            source: SubscriptionSource,
        ) {
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
            router.push(
                route: RouteSheet(
                    type: .subscriptionChange,
                    arguments: SubscriptionChangeArguments(
                        source: source,
                    ),
                ),
            )
            let model = SubscriptionChangeViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: {
                    nil
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
                    source: source,
                ),
            )
            #expect(
                router.path.count == 1,
            )
            #expect(
                model.descriptionKey == (source == .apple ? .subscriptionChangeAppleDescription : .subscriptionChangeDescription),
            )
            model.onTapConfirm()
            #expect(
                router.sheet == nil && router.path.count == 2,
            )
        }

        @Test
        func dismissingChangeConfirmationKeepsTheCurrentScreen() {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            let model = SubscriptionChangeViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: {
                    nil
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
            model.onDisappear()
            #expect(
                router.path.isEmpty,
            )
        }

        @Test
        func renewalDisablingWaitsForConfirmationAndSuccessfulServerResponse() async {
            var calls = 0
            var notifications = 0
            let model = makeDisablingModel(
                onDisableSuccess: {
                    notifications += 1
                },
            ) {
                calls += 1
                #expect(
                    notifications == 0,
                )
            }
            #expect(
                calls == 0 && !model.isProcessing,
            )
            model.onTapConfirm()
            model.onTapConfirm()
            #expect(
                model.isProcessing && model.router.sheet?.type == .subscriptionAutoRenewalDisabling,
            )
            await model.operationTask?.value
            #expect(
                calls == 1 && notifications == 1 && model.router.sheet == nil,
            )
            model.onDisappear()
        }

        @Test
        func failedDisablingKeepsTheSheetOpenAndAllowsRetry() async {
            var calls = 0
            var notifications = 0
            let model = makeDisablingModel(
                onDisableSuccess: {
                    notifications += 1
                },
            ) {
                calls += 1
                if calls == 1 {
                    throw URLError(
                        .notConnectedToInternet,
                    )
                }
            }
            model.onTapConfirm()
            await model.operationTask?.value
            #expect(
                !model.isProcessing && model.router.sheet?.type == .subscriptionAutoRenewalDisabling && notifications == 0,
            )
            model.onTapConfirm()
            await model.operationTask?.value
            #expect(
                calls == 2 && notifications == 1 && model.router.sheet == nil,
            )
            model.onDisappear()
        }

        @Test(
            arguments: [false, true],
        )
        func dismissedDisablingIgnoresLateSuccessAndFailure(
            isFailure: Bool,
        ) async {
            var response: CheckedContinuation<Void, Never>?
            let model = makeDisablingModel {
                await withCheckedContinuation {
                    response = $0
                }
                if isFailure {
                    throw URLError(
                        .notConnectedToInternet,
                    )
                }
            }
            model.onTapConfirm()
            while response == nil {
                await Task.yield()
            }
            let task = model.operationTask
            model.onDisappear()
            model.router.dismissSheet()
            let next = RouteSheet(
                type: SheetType.about,
            )
            model.router.push(
                route: next,
            )
            response?.resume()
            await task?.value
            #expect(
                model.router.sheet?.id == next.id,
            )
        }

        @Test
        func dismissingBeforeDisablingStartsDoesNotSendARequest() async {
            var calls = 0
            let model = makeDisablingModel {
                calls += 1
            }
            model.onTapConfirm()
            let task = model.operationTask
            model.onDisappear()
            await task?.value
            #expect(
                calls == 0,
            )
        }

        private func makeDisablingModel(
            onDisableSuccess: (() -> Void)? = nil,
            operation: @escaping () async throws -> Void,
        ) -> SubscriptionAutoRenewalDisablingViewModel {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .menu,
                ),
            )
            router.push(
                route: RouteSheet(
                    type: .subscriptionAutoRenewalDisabling,
                ),
            )
            return SubscriptionAutoRenewalDisablingViewModel(
                messager: DMessager(),
                container: container,
                router: router,
                getSubscriptionStatus: {
                    SubscriptionManagePreviewFactory.makeStatus(
                        source: .robokassa,
                    )
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: SubscriptionAutoRenewalDisablingArguments(
                    onDisableSuccess: onDisableSuccess,
                ),
                disableAutoRenewal: operation,
            )
        }
    }
#endif
