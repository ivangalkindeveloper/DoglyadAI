#if DEBUG
    import Combine
    @testable import Doglyad
    import Testing

    @MainActor
    struct LoadingStatePublicationTests {
        @Test
        func changingLoadingScenarioPublishesEvenWithTheSameRetainedData() {
            let subscription = ManageSubscriptionInactiveState(
                catalog: ModulePreviewFactory.development.products,
            )
            let recovery = SubscriptionRecoveryInitialState()
            let paywall = ModulePreviewFactory.paywallContent
            let scenarios: [[Any]] = [
                [
                    ManageSubscriptionCatalogLoadingState(
                        previousState: subscription,
                    ),
                    ManageSubscriptionRestoreLoadingState(
                        previousState: subscription,
                    ),
                    ManageSubscriptionManagementLoadingState(
                        previousState: subscription,
                    ),
                    ManageSubscriptionRefundLoadingState(
                        previousState: subscription,
                    ),
                    ManageSubscriptionRefreshLoadingState(
                        previousState: subscription,
                    ),
                ],
                [
                    SubscriptionRecoveryKeyCreationLoadingState(
                        previousState: recovery,
                    ),
                    SubscriptionRecoveryRestoreLoadingState(
                        previousState: recovery,
                    ),
                ],
                [PaywallRestoreLoadingState(
                    previousState: paywall,
                ), PaywallPurchaseLoadingState(
                    content: paywall,
                    plan: paywall.selectedPlan!,
                )],
            ]
            for states in scenarios {
                let model = DStateViewModel<Any>(
                    state: states[
                        0,
                    ],
                )
                var publications = 0
                let observation = model.$state.dropFirst().sink { _ in
                    publications += 1
                }
                for state in states.dropFirst() {
                    model.emit(
                        state,
                        animation: nil,
                    )
                }
                #expect(
                    publications == states.count - 1,
                )
                observation.cancel()
            }
        }

        @Test
        func repeatingTheSameLoadingSnapshotDoesNotPublish() {
            let model = DStateViewModel<any PaywallStateProtocol>(
                state: PaywallCatalogLoadingState(),
            )
            var publications = 0
            let observation = model.$state.dropFirst().sink { _ in
                publications += 1
            }
            model.emit(
                PaywallCatalogLoadingState(),
                animation: nil,
            )
            #expect(
                publications == 0,
            )
            observation.cancel()
        }
    }
#endif
