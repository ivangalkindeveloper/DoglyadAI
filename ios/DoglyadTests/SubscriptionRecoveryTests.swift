#if DEBUG
    import Combine
    @testable import Doglyad
    @testable import DoglyadUI
    import Foundation
    import Router
    import Testing

    @MainActor
    struct SubscriptionRecoveryTests {
        init() {}

        @Test
        func enteredKeyIsRetainedWhenAnOperationFails() async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let messager = DMessager()
            let model = SubscriptionRecoveryPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .subscriptionManage,
                    ),
                ),
                isFailure: true,
                messager: messager,
            )
            model.recoveryTextController.setText(
                "Wrong-Key",
            )
            model.onTapRestore()
            await model.operationTask?.value
            #expect(
                model.state is SubscriptionRecoveryInitialState,
            )
            #expect(
                model.recoveryTextController.text == "Wrong-Key",
            )
            #expect(
                messager.message?.description.map {
                    String(
                        localized: $0,
                    )
                } == container.l10n.text(
                    .errorUnknownDescription,
                ),
            )
            model.onDisappear()
        }

        @Test
        func restoringTrimsInputAndReturnsToManagement() async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .subscriptionManage,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .subscriptionRecovery,
                ),
            )
            var recoveredKey: String?
            let model = SubscriptionRecoveryPreviewFactory.makeViewModel(
                container: container,
                router: router,
                onRecover: {
                    recoveredKey = $0
                },
            )
            model.recoveryTextController.setText(
                "  Saved-MixedCase-Key  ",
            )
            model.onTapRestore()
            await model.operationTask?.value
            #expect(
                recoveredKey == "Saved-MixedCase-Key" && router.path.isEmpty,
            )
            model.onDisappear()
        }

        @Test(
            arguments: [false, true],
            [false, true],
        )
        func leavingDiscardsLateRecoverySuccessAndFailure(
            isFailure: Bool,
            isDisappearance: Bool,
        ) async {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .subscriptionManage,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .subscriptionRecovery,
                ),
            )
            let messager = DMessager()
            var response: CheckedContinuation<Void, Never>?
            var updates = 0
            var completions = 0
            let model = SubscriptionRecoveryViewModel(
                messager: messager,
                container: container,
                router: router,
                getSubscriptionStatus: {
                    nil
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in
                    updates += 1
                },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: SubscriptionRecoveryArguments(
                    onRecovered: {
                        completions += 1
                    },
                ),
                recover: { _ in
                    await withCheckedContinuation {
                        response = $0
                    }
                    if isFailure {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    return SubscriptionManagePreviewFactory.makeStatus(
                        source: .robokassa,
                    )
                },
            )
            model.recoveryTextController.setText(
                "Recovery-Key",
            )
            model.onTapRestore()
            while response == nil {
                await Task.yield()
            }
            let task = model.operationTask
            if isDisappearance {
                model.onDisappear()
            } else {
                model.onTapBack()
            }
            let closedState = model.state
            let routeCount = router.path.count
            response?.resume()
            await task?.value
            #expect(
                model.state === closedState,
            )
            #expect(
                updates == 0 && completions == 0 && messager.message == nil,
            )
            #expect(
                router.path.count == routeCount,
            )
            if !isDisappearance {
                model.onDisappear()
            }
        }
    }
#endif
