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
            let paywall = PaywallCatalogLoadingState()
            let scenarios: [[Any]] = [
                [HistoryReportsLoadingState(), HistoryPaginationLoadingState()],
                [SelectTemplateTemplatesLoadingState(), SelectTemplateSelectionLoadingState()],
                [StorageProtocolsClearLoadingState(), StorageSpeechModelDeleteLoadingState(), StorageAllClearLoadingState()],
                [TemplateAddInitializationLoadingState(), TemplateAddSaveLoadingState()],
                [TemplateEditInitializationLoadingState(), TemplateEditSaveLoadingState(), TemplateEditDeleteLoadingState()],
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
                ), PaywallPaymentCheckLoadingState(
                    previousState: paywall,
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
            let model = DStateViewModel<any HistoryStateProtocol>(
                state: HistoryReportsLoadingState(),
            )
            var publications = 0
            let observation = model.$state.dropFirst().sink { _ in
                publications += 1
            }
            model.emit(
                HistoryReportsLoadingState(),
                animation: nil,
            )
            #expect(
                publications == 0,
            )
            observation.cancel()
        }
    }
#endif
