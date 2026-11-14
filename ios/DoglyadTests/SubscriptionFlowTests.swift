#if DEBUG
    import Combine
    @testable import Doglyad
    @testable import DoglyadUI
    import Foundation
    import Router
    import SwiftUI
    import Testing

    @MainActor
    struct SubscriptionFlowTests {
        init() {}

        @Test(
            arguments: [ScreenType.onBoarding, .scan, .subscriptionManage, .reportDetail],
        )
        func recoveryReturnsThroughPaywallWithoutPoppingItsOrigin(
            origin: ScreenType,
        ) async throws {
            let container = PaywallPreviewFactory.makeContainer()
            let status = CurrentValueSubject<SubscriptionStatus?, Never>(
                nil,
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
            let paywall = makePaywall(
                container: container,
                router: router,
                statuses: status,
            )
            paywall.onAppear()
            await paywall.lastTask?.value
            let recoveryDepth = router.path.count + 1
            paywall.onTapRestore()
            #expect(
                router.path.count == recoveryDepth,
            )
            paywall.onTapClose()
            #expect(
                router.path.count == recoveryDepth,
            )
            let messager = DMessager()
            let recovered = SubscriptionManagePreviewFactory.makeStatus(
                source: .robokassa,
            )
            let recovery = SubscriptionRecoveryViewModel(
                messager: messager,
                container: container,
                router: router,
                getSubscriptionStatus: {
                    status.value
                },
                observeSubscriptionStatus: {
                    status.sink(
                        receiveValue: $0,
                    )
                },
                onSubscriptionStatusUpdated: {
                    status.send(
                        $0,
                    )
                },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: SubscriptionRecoveryArguments(
                    onRecovered: {
                        paywall.onTapClose()
                    },
                ),
                recover: { _ in
                    status.send(
                        recovered,
                    )
                    #expect(
                        router.path.count == recoveryDepth,
                    )
                    return recovered
                },
            )
            recovery.recoveryTextController.setText(
                "DEMO-KEY",
            )
            recovery.onTapRestore()
            await recovery.operationTask?.value
            #expect(
                router.path.count == originDepth,
            )
            #expect(
                messager.message?.type == .success,
            )
            #expect(
                status.value == recovered,
            )
            recovery.onDisappear()
            paywall.onDisappear()
        }

        @Test
        func inactiveRecoveryKeepsTheFormAndDoesNotCompletePaywall() async {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .paywall,
                ),
            )
            router.push(
                route: RouteScreen(
                    type: .subscriptionRecovery,
                ),
            )
            let messager = DMessager()
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
                onSubscriptionStatusUpdated: { _ in },
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
                    nil
                },
            )
            model.recoveryTextController.setText(
                "INACTIVE-DEMO-KEY",
            )
            model.onTapRestore()
            await model.operationTask?.value
            #expect(
                router.path.count == 1 && completions == 0,
            )
            #expect(
                model.state is SubscriptionRecoveryInitialState,
            )
            #expect(
                model.recoveryTextController.text == "INACTIVE-DEMO-KEY" && messager.message?.type == .error,
            )
            #expect(
                messager.message.map {
                    String(
                        localized: $0.title,
                    )
                } == container.l10n.text(
                    .subscriptionRecoveryNoActiveTitle,
                ),
            )
            #expect(
                messager.message?.description.map {
                    String(
                        localized: $0,
                    )
                } == container.l10n.text(
                    .subscriptionRecoveryNoActiveDescription,
                ),
            )
            model.onDisappear()
        }

        @Test(
            arguments: ["ru", "en"],
        )
        func footerContainsBothDocumentLinksAndOpensTheMatchingSheet(
            code: String,
        ) throws {
            let container = SubscriptionManagePreviewFactory.makeContainer(
                code: code,
            )
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .paywall,
                ),
            )
            let model = makePaywall(
                container: container,
                router: router,
                statuses: CurrentValueSubject(
                    nil,
                ),
            )
            let text = model.legalAttributedText(
                theme: .light,
                locale: container.l10n.locale,
            )
            #expect(
                String(
                    text.characters,
                ) == container.l10n.text(
                    .paywallAutoRenewalDescription,
                ),
            )
            let links = Set(
                text.runs.compactMap(
                    \.link,
                ),
            )
            #expect(
                links == [container.applicationConfig.privacyPolicyUrl, container.applicationConfig.termsAndConditionsUrl],
            )
            _ = model.onLegalAttributedEnvironment(
                url: container.applicationConfig.privacyPolicyUrl,
            )
            #expect(
                (router.sheet?.arguments as? WebDocumentArguments)?.url == container.applicationConfig.privacyPolicyUrl,
            )
            _ = model.onLegalAttributedEnvironment(
                url: container.applicationConfig.termsAndConditionsUrl,
            )
            #expect(
                (router.sheet?.arguments as? WebDocumentArguments)?.url == container.applicationConfig.termsAndConditionsUrl,
            )
        }

        @Test
        func statusReadFailureCannotReuseAnOldActiveSubscriptionAsSuccess() async {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let active = SubscriptionManagePreviewFactory.makeStatus(
                source: .robokassa,
            )
            var reads = 0
            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: DRouter(
                    initialRoute: RouteScreen(
                        type: .subscriptionManage,
                    ),
                ),
                status: active,
                fetchSubscriptionStatus: {
                    reads += 1
                    if reads == 1 {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    return active
                },
            )
            model.onAppear()
            await model.lastTask?.value
            #expect(
                model.state is SubscriptionManageErrorState,
            )
            model.onTapRetry()
            #expect(
                model.state is SubscriptionManageCatalogLoadingState,
            )
            await model.lastTask?.value
            #expect(
                model.state is SubscriptionManageActiveState && reads == 2,
            )
            model.onDisappear()
        }

        @Test(
            arguments: [false, true],
        )
        func successfulDisablingRefreshesStatusWithScreenLoadingAndHandlesReadFailure(
            isFailure: Bool,
        ) async throws {
            let container = SubscriptionManagePreviewFactory.makeContainer()
            let router = DRouter(
                initialRoute: RouteScreen(
                    type: .subscriptionManage,
                ),
            )
            var reads = 0
            var disableCalls = 0
            var disableResponse: CheckedContinuation<Void, Never>?
            var statusResponse: CheckedContinuation<Void, Never>?
            let parent = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: SubscriptionManagePreviewFactory.makeStatus(
                    source: .robokassa,
                ),
                fetchSubscriptionStatus: {
                    reads += 1
                    if reads == 1 {
                        return SubscriptionManagePreviewFactory.makeStatus(
                            source: .robokassa,
                        )
                    }
                    await withCheckedContinuation {
                        statusResponse = $0
                    }
                    if isFailure {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    return SubscriptionManagePreviewFactory.makeStatus(
                        source: .robokassa,
                        isAutoRenewing: false,
                    )
                },
            )
            parent.onAppear()
            await parent.lastTask?.value
            parent.onTapDisableAutoRenewal()
            let arguments = try #require(
                router.sheet?.arguments as? SubscriptionAutoRenewalDisablingArguments,
            )
            #expect(
                arguments.onDisableSuccess != nil,
            )
            let messager = DMessager()
            let sheet = SubscriptionAutoRenewalDisablingViewModel(
                messager: messager,
                container: container,
                router: router,
                getSubscriptionStatus: {
                    parent.subscriptionStatus
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: arguments,
                disableAutoRenewal: {
                    disableCalls += 1
                    await withCheckedContinuation {
                        disableResponse = $0
                    }
                },
            )
            sheet.onTapConfirm()
            while disableResponse == nil {
                await Task.yield()
            }
            #expect(
                reads == 1 && parent.state is SubscriptionManageActiveState,
            )
            disableResponse?.resume()
            await sheet.operationTask?.value
            while statusResponse == nil {
                await Task.yield()
            }
            #expect(
                disableCalls == 1 && reads == 2 && parent.state is SubscriptionManageRefreshLoadingState,
            )
            #expect(
                router.sheet == nil && messager.message?.type == .success,
            )
            statusResponse?.resume()
            await parent.operationTask?.value
            if isFailure {
                #expect(
                    parent.state is SubscriptionManageErrorState,
                )
            } else {
                let active = try #require(
                    parent.state as? SubscriptionManageActiveState,
                )
                #expect(
                    !active.status.isAutoRenewing,
                )
                parent.onTapDisableAutoRenewal()
                #expect(
                    router.sheet == nil,
                )
            }
            sheet.onDisappear()
            parent.onDisappear()
        }

        private func makePaywall(
            container: DependencyContainer,
            router: DRouter,
            statuses: CurrentValueSubject<SubscriptionStatus?, Never>,
        ) -> PaywallViewModel {
            PaywallViewModel(
                messager: DMessager(),
                container: container,
                router: router,
                getSubscriptionStatus: {
                    statuses.value
                },
                observeSubscriptionStatus: {
                    statuses.sink(
                        receiveValue: $0,
                    )
                },
                onSubscriptionStatusUpdated: {
                    statuses.send(
                        $0,
                    )
                },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: nil,
                purchase: { _, _ in
                    .cancelled
                },
                restorePurchases: {
                    .completed(
                        isOwnerChanged: false,
                    )
                },
                checkPurchase: {
                    .pending
                },
            )
        }
    }
#endif
