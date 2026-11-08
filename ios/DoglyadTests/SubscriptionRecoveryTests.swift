#if DEBUG
    @testable import Doglyad
    import Foundation
    import Router
    import Testing

    @MainActor
    struct SubscriptionRecoveryTests {
        @Test
        func generatedKeyIsRetainedWhenAnOperationFails() async throws {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let model = SubscriptionRecoveryPreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .manageSubscription,
                    ),
                ),
                isFailure: true,
            )
            model.emit(
                SubscriptionRecoverySuccessState(
                    key: "Saved-MixedCase-Key",
                ),
            )
            model.recoveryTextController.setText(
                "Wrong-Key",
            )
            model.onTapRestore()
            await model.operationTask?.value
            let failed = try #require(
                model.state as? SubscriptionRecoveryFailedState,
            )
            #expect(
                (failed.previousState as? SubscriptionRecoverySuccessState)?.key == "Saved-MixedCase-Key",
            )
            #expect(
                model.recoveryTextController.text == "Wrong-Key",
            )
            model.onDisappear()
        }

        @Test
        func creatingAKeyAndRestoringHaveSeparateActions() async throws {
            let container = ManageSubscriptionPreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .manageSubscription,
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
            #expect(
                !model.isRestoreEnabled,
            )
            model.onTapCreateKey()
            await model.operationTask?.value
            let key = try #require(
                model.state as? SubscriptionRecoverySuccessState,
            )
            #expect(
                key.key == "Preview-MixedCase-Recovery-Key" && router.path.count == 1,
            )
            model.recoveryTextController.setText(
                "  Saved-MixedCase-Key  ",
            )
            #expect(
                model.isRestoreEnabled,
            )
            model.onTapRestore()
            await model.operationTask?.value
            #expect(
                recoveredKey == "Saved-MixedCase-Key" && router.path.isEmpty,
            )
            model.onDisappear()
        }
    }
#endif
