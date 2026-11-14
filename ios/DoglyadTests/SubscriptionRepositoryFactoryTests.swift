@testable import Doglyad
import Foundation
import Testing

@MainActor
struct SubscriptionRepositoryFactoryTests {
    init() {}

    @Test(
        arguments: [String?.none, "USA", "RUS"],
    )
    func factorySelectsPurchasesByStorefront(
        countryCode: String?,
    ) async {
        var reads = 0
        let factory = SubscriptionRepositoryFactory(
            backend: SubscriptionTestBackendRepository(),
            getStorefrontCountryCode: {
                reads += 1
                return countryCode
            },
        )
        #expect(
            reads == 0,
        )
        let repository = await factory.make()
        #expect(
            (repository is SubscriptionRobokassaRepository) == (countryCode == "RUS"),
        )
        #expect(
            (repository is SubscriptionStoreKitRepository) == (countryCode != "RUS"),
        )
        #expect(
            await factory.make() !== repository,
        )
        #expect(
            reads == 2,
        )
    }

    @Test(
        arguments: [SubscriptionSource.apple, .robokassa],
        [false, true],
    )
    func restorationReturnsAccessOrRequestsARecoveryKey(
        source: SubscriptionSource,
        isRestorable: Bool,
    ) async throws {
        let backend = SubscriptionTestBackendRepository()
        let apple = SubscriptionTestRepository(
            backend: backend,
        )
        apple.isRestorableSubscriptionAvailable = isRestorable
        let robokassa = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        let root = SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: apple,
                robokassa: robokassa,
                getStorefrontCountryCode: {
                    source == .robokassa ? "RUS" : "USA"
                },
            ),
        )
        switch try await root.restorePurchases() {
        case .completed:
            #expect(
                source == .apple,
            )
            #expect(
                (root.status != nil) == isRestorable,
            )
            if let status = root.status {
                #expect(
                    status == backend.status,
                )
            }
        case .recoveryKeyRequired:
            #expect(
                source == .robokassa,
            )
            #expect(
                root.status == nil,
            )
        }
        #expect(
            apple.restoreCount == (source == .apple ? 1 : 0),
        )
        #expect(
            robokassa.restoreCount == (source == .robokassa ? 1 : 0),
        )
    }

    @Test
    func factoryReadsStorefrontPerOperationWhileExistingPurchasesKeepTheirProvider() async throws {
        let backend = SubscriptionTestBackendRepository()
        let apple = SubscriptionTestRepository(
            backend: backend,
        )
        let robokassa = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        var countryCode = "USA"
        var reads = 0
        let container = makeSubscriptionTestContainer(
            backend: backend,
            storeKit: apple,
            robokassa: robokassa,
            getStorefrontCountryCode: {
                reads += 1
                return countryCode
            },
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        #expect(
            reads == 0,
        )
        let first = await container.subscriptionRepositoryFactory.make()
        #expect(
            try await first.fetchCatalog().plans == [apple.plan],
        )
        countryCode = "RUS"
        let second = await container.subscriptionRepositoryFactory.make()
        #expect(
            try await second.fetchCatalog().plans == [robokassa.plan],
        )
        #expect(
            reads == 2,
        )
        backend.isAccessAvailable = true
        backend.status = SubscriptionStatus(
            planId: "monthly",
            type: .pro,
            entitlement: backend.status.entitlement,
            availableCountPerDay: 20,
            source: .apple,
        )
        await root.refreshStatus()
        try await root.manageSubscription()
        try await root.requestRefund()
        _ = try await root.restorePurchases()
        #expect(
            apple.manageCount == 1 && apple.refundCount == 1 && apple.restoreCount == 1,
        )
        #expect(
            robokassa.manageCount == 0 && robokassa.refundCount == 0 && robokassa.restoreCount == 0,
        )
        #expect(
            reads == 2,
        )
    }

    @Test
    func pendingExternalPaymentSurvivesSwitchToAppleStorefront() async throws {
        let backend = SubscriptionTestBackendRepository()
        let apple = SubscriptionTestRepository(
            backend: backend,
        )
        let robokassa = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        let id = UUID()
        robokassa.preparedPaymentID = id
        robokassa.purchaseResult = .pending
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: "monthly",
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        var countryCode = "RUS"
        let container = makeSubscriptionTestContainer(
            backend: backend,
            storeKit: apple,
            robokassa: robokassa,
            getStorefrontCountryCode: {
                countryCode
            },
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let outcome = try await root.purchase(
            plan: robokassa.plan,
        )
        switch outcome {
        case .pending: break
        case .cancelled, .completed:
            Issue.record(
                "Expected a pending payment",
            )
        }
        countryCode = "USA"
        #expect(
            await container.subscriptionRepositoryFactory.make() === apple,
        )
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: "monthly",
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        backend.isAccessAvailable = true
        backend.status = SubscriptionStatus(
            planId: "monthly",
            type: .pro,
            entitlement: backend.status.entitlement,
            availableCountPerDay: 20,
            source: .robokassa,
        )
        await root.refreshStatus()
        #expect(
            root.status == backend.status,
        )
        let checkedCount = backend.checkedPayments.count
        await root.refreshStatus()
        #expect(
            backend.checkedPayments.count == checkedCount,
        )
        await #expect(
            throws: SubscriptionError.self,
        ) {
            try await root.manageSubscription()
        }
        #expect(
            robokassa.manageCount == 0 && apple.manageCount == 0,
        )
    }

    @Test
    func recoveryStopsCheckingThePreviousOwnersPendingPayment() async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        let id = UUID()
        provider.preparedPaymentID = id
        provider.purchaseResult = .pending
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: "monthly",
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let root = SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: provider,
                robokassa: provider,
                getStorefrontCountryCode: {
                    "RUS"
                },
            ),
        )
        _ = try await root.purchase(
            plan: provider.plan,
        )
        let checkedCount = backend.checkedPayments.count
        _ = try await root.recover(
            key: "test-key",
        )
        await root.refreshStatus()
        #expect(
            backend.checkedPayments.count == checkedCount,
        )
    }

    @Test
    func overlappingPurchasesAreRejectedByTheRoot() async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
        )
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        provider.onPurchase = {
            for await _ in stream {}
        }
        let root = SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: provider,
                robokassa: provider,
                getStorefrontCountryCode: {
                    "USA"
                },
            ),
        )
        let first = Task {
            try await root.purchase(
                plan: provider.plan,
            )
        }
        for _ in 0 ..< 100 {
            if provider.purchaseCount == 1 {
                break
            }
            await Task.yield()
        }
        #expect(
            provider.purchaseCount == 1,
        )
        do {
            _ = try await root.purchase(
                plan: provider.plan,
            )
            Issue.record(
                "A second purchase must be rejected",
            )
        } catch let error as SubscriptionError {
            switch error {
            case .purchasePending: break
            case .offeringsUnavailable, .unverifiedTransaction:
                Issue.record(
                    "Unexpected rejection",
                )
            }
        }
        continuation.finish()
        _ = try await first.value
        #expect(
            provider.purchaseCount == 1,
        )
    }

    @Test(
        arguments: [BillingPaymentState.canceled, .refunded],
    )
    func terminalExternalPaymentReturnsToPlanSelection(
        state: BillingPaymentState,
    ) async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        let id = UUID()
        provider.preparedPaymentID = id
        provider.purchaseResult = .pending
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: "monthly",
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let root = SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: provider,
                robokassa: provider,
                getStorefrontCountryCode: {
                    "RUS"
                },
            ),
        )
        _ = try await root.purchase(
            plan: provider.plan,
        )
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: "monthly",
            status: state,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        switch try await root.checkPurchase() {
        case .cancelled: break
        case .pending, .completed:
            Issue.record(
                "A terminal canceled payment must allow another selection",
            )
        }
        #expect(
            root.status == nil,
        )
    }

    @Test
    func aPlanFromThePreviousStorefrontCannotStartAPurchase() async throws {
        let backend = SubscriptionTestBackendRepository()
        let apple = SubscriptionTestRepository(
            backend: backend,
        )
        let robokassa = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        var countryCode = "USA"
        let container = makeSubscriptionTestContainer(
            backend: backend,
            storeKit: apple,
            robokassa: robokassa,
            getStorefrontCountryCode: {
                countryCode
            },
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let repository = await container.subscriptionRepositoryFactory.make()
        let plans = try await repository.fetchCatalog().plans
        countryCode = "RUS"
        do {
            _ = try await root.purchase(
                plan: plans[
                    0,
                ],
            )
            Issue.record(
                "A changed provider requires refreshed prices before buying",
            )
        } catch let error as SubscriptionError {
            switch error {
            case .offeringsUnavailable: break
            case .unverifiedTransaction, .purchasePending:
                Issue.record(
                    "Unexpected rejection",
                )
            }
        }
        #expect(
            apple.purchaseCount == 0 && robokassa.purchaseCount == 0,
        )
    }

    @Test
    func aPendingPurchaseIsNotCompletedByAnExistingPaidSubscription() async throws {
        let backend = SubscriptionTestBackendRepository()
        backend.isAccessAvailable = true
        let provider = SubscriptionTestRepository(
            backend: backend,
        )
        provider.purchaseResult = .pending
        let root = SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: provider,
                robokassa: provider,
                getStorefrontCountryCode: {
                    "USA"
                },
            ),
        )
        switch try await root.purchase(
            plan: provider.plan,
        ) {
        case .pending: break
        case .completed, .cancelled:
            Issue.record(
                "Existing access does not complete a new pending purchase",
            )
        }
    }
}
