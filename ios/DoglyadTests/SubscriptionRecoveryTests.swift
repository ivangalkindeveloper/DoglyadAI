#if DEBUG
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
    }
#endif
