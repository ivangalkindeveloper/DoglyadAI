@testable import Doglyad
import Foundation
import Testing

@MainActor
struct SubscriptionPurchaseVerificationTests {
    init() {}

    @Test
    func verifiedRobokassaPurchaseFetchesAccessWithoutRepeatingPaymentVerification() async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        provider.preparedPaymentID = UUID()
        provider.purchaseResult = .completed
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        guard case let .completed(
            status,
        ) = try await root.purchase(
            plan: provider.plan,
        ) else {
            Issue.record(
                "The verified provider result must complete the purchase",
            )
            return
        }
        #expect(
            status?.planId == provider.plan.id,
        )
        #expect(
            backend.checkedPayments.isEmpty,
        )
        #expect(
            backend.statusRequestCount == 1,
        )
    }

    @Test
    func pendingRobokassaPurchaseChecksOnlyThePaymentUntilItSucceeds() async throws {
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
            planId: provider.plan.id,
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: nil,
        )
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        #expect(
            backend.checkedPayments.isEmpty,
        )
        #expect(
            backend.statusRequestCount == 0,
        )
        try await assertPending(
            root.checkPurchase(),
        )
        #expect(
            backend.checkedPayments == [id],
        )
        #expect(
            backend.statusRequestCount == 0,
        )
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: provider.plan.id,
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: nil,
        )
        backend.isAccessAvailable = true
        backend.status.source = .robokassa
        guard case .completed = try await root.checkPurchase() else {
            Issue.record(
                "Confirmed payment and access must complete the purchase",
            )
            return
        }
        #expect(
            backend.checkedPayments == [id, id],
        )
        #expect(
            backend.statusRequestCount == 1,
        )
    }

    @Test
    func canceledPurchaseDoesNotFetchPaymentOrSubscriptionAgain() async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        provider.preparedPaymentID = UUID()
        provider.purchaseResult = .cancelled
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        guard case .cancelled = try await root.purchase(
            plan: provider.plan,
        ) else {
            Issue.record(
                "The provider cancellation must return to plan selection",
            )
            return
        }
        #expect(
            backend.checkedPayments.isEmpty,
        )
        #expect(
            backend.statusRequestCount == 0,
        )
    }

    @Test(
        arguments: [BillingPaymentState.pending, .needsReview, .created],
    )
    func existingAccessCannotCompleteUnconfirmedRobokassaPayment(
        paymentState: BillingPaymentState,
    ) async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        let id = UUID()
        provider.preparedPaymentID = id
        provider.purchaseResult = .pending
        backend.isAccessAvailable = true
        backend.status.source = .robokassa
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: provider.plan.id,
            status: paymentState,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        root.update(
            status: backend.status,
        )
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        try await assertPending(
            root.checkPurchase(),
        )
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: provider.plan.id,
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        switch try await root.checkPurchase() {
        case let .completed(
            status,
        ):
            #expect(
                status?.planId == provider.plan.id,
            )
        case .cancelled, .pending:
            Issue.record(
                "The exact confirmed payment must complete the purchase",
            )
        }
    }

    @Test(
        arguments: [false, true],
    )
    func paymentIdentityAndPlanMustMatchThePreparedPurchase(
        isWrongPlan: Bool,
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
            planId: provider.plan.id,
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        backend.isAccessAvailable = true
        backend.status.source = .robokassa
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: isWrongPlan ? id : UUID(),
            planId: isWrongPlan ? "other-plan" : provider.plan.id,
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: "bank_card",
        )
        await #expect(
            throws: SubscriptionError.self,
        ) {
            try await root.checkPurchase()
        }
    }

    @Test
    func confirmedSelectedPaymentPreservesDifferentCurrentAccess() async throws {
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
            planId: provider.plan.id,
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: nil,
        )
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        backend.isAccessAvailable = true
        backend.status = SubscriptionStatus(
            planId: "annual",
            type: .pro,
            entitlement: backend.status.entitlement,
            availableCountPerDay: 20,
            source: .robokassa,
        )
        backend.payments[
            id,
        ] = BillingPaymentResponse(
            id: id,
            planId: provider.plan.id,
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: nil,
        )
        switch try await root.checkPurchase() {
        case let .completed(
            status,
        ):
            #expect(
                status?.planId == "annual",
            )
        case .pending, .cancelled:
            Issue.record(
                "Confirmed payment must preserve the existing stronger or longer access",
            )
        }
    }

    @Test
    func pendingApplePurchaseRequiresANewVerifiedTransactionForTheSelectedPlan() async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
        )
        provider.purchaseResult = .pending
        backend.isAccessAvailable = true
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        root.onInit()
        for _ in 0 ..< 100 {
            if provider.observationCount == 1 {
                break
            }
            await Task.yield()
        }
        #expect(
            provider.observationCount == 1,
        )
        await root.lastTask?.value
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        for update in [
            SubscriptionTransactionUpdate(
                transactionId: 2,
                planId: provider.plan.id,
                purchaseDate: Date(),
                isActive: false,
                isOwnerChanged: false,
            ),
            SubscriptionTransactionUpdate(
                transactionId: 1,
                planId: provider.plan.id,
                purchaseDate: Date(),
                isActive: true,
                isOwnerChanged: false,
            ),
            SubscriptionTransactionUpdate(
                transactionId: 2,
                planId: "other-plan",
                purchaseDate: Date(),
                isActive: true,
                isOwnerChanged: false,
            ),
            SubscriptionTransactionUpdate(
                transactionId: 2,
                planId: provider.plan.id,
                purchaseDate: .distantPast,
                isActive: true,
                isOwnerChanged: false,
            ),
        ] {
            await deliver(
                update,
                provider: provider,
                root: root,
            )
            try await assertPending(
                root.checkPurchase(),
            )
        }
        await deliver(
            SubscriptionTransactionUpdate(
                transactionId: 2,
                planId: provider.plan.id,
                purchaseDate: Date(),
                isActive: true,
                isOwnerChanged: false,
            ),
            provider: provider,
            root: root,
        )
        switch try await root.checkPurchase() {
        case let .completed(
            status,
        ):
            #expect(
                status?.planId == provider.plan.id,
            )
        case .pending, .cancelled:
            Issue.record(
                "A new verified transaction for the selected plan must complete",
            )
        }
    }

    @Test
    func firstApplePurchaseAcceptsAVerifiedTransactionWithoutAPreviousSnapshot() throws {
        let context: SubscriptionPurchaseContextProtocol = SubscriptionStoreKitPurchaseContext(
            planID: "monthly",
            previousTransactionID: nil,
            previousPurchaseDate: nil,
        )
        let result = try #require(
            context.check(
                transaction: SubscriptionTransactionUpdate(
                    transactionId: 1,
                    planId: "monthly",
                    purchaseDate: Date(),
                    isActive: true,
                    isOwnerChanged: false,
                ),
            ),
        )
        guard case .completed = result else {
            Issue.record(
                "A verified first purchase must be accepted without a previous transaction",
            )
            return
        }
    }

    @Test(
        arguments: [false, true],
    )
    func latePaymentCheckCannotRestoreThePreviousOwnersPurchase(
        isCheckFailing: Bool,
    ) async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        let paymentID = UUID()
        provider.preparedPaymentID = paymentID
        provider.purchaseResult = .pending
        backend.payments[
            paymentID,
        ] = BillingPaymentResponse(
            id: paymentID,
            planId: provider.plan.id,
            status: .succeeded,
            confirmationUrl: nil,
            paymentMethodType: nil,
        )
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        defer {
            continuation.finish()
        }
        backend.onCheckPayment = {
            for await _ in stream {}
            if isCheckFailing {
                throw SubscriptionError.offeringsUnavailable
            }
        }
        let checking = Task {
            try await root.checkPurchase()
        }
        for _ in 0 ..< 1000 {
            if !backend.checkedPayments.isEmpty {
                break
            }
            await Task.yield()
        }
        #expect(
            backend.checkedPayments == [paymentID],
        )
        backend.status = SubscriptionStatus(
            planId: "recovered-plan",
            type: .base,
            entitlement: backend.status.entitlement,
            availableCountPerDay: 5,
            source: .robokassa,
        )
        let recovered = try await root.recover(
            key: "another-owner",
        )
        continuation.finish()
        await #expect(
            throws: CancellationError.self,
        ) {
            try await checking.value
        }
        #expect(
            root.status == recovered,
        )
        #expect(
            backend.statusRequestCount == 0,
        )
        try await assertPending(
            root.checkPurchase(),
        )
        #expect(
            backend.checkedPayments == [paymentID],
        )
    }

    @Test
    func appleUpdatesCannotConfirmAPendingRobokassaPayment() async throws {
        let backend = SubscriptionTestBackendRepository()
        let apple = SubscriptionTestRepository(
            backend: backend,
        )
        let robokassa = SubscriptionTestRepository(
            backend: backend,
            source: .robokassa,
        )
        let paymentID = UUID()
        robokassa.preparedPaymentID = paymentID
        robokassa.purchaseResult = .pending
        backend.payments[
            paymentID,
        ] = BillingPaymentResponse(
            id: paymentID,
            planId: robokassa.plan.id,
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: nil,
        )
        let root = SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: apple,
                robokassa: robokassa,
                getStorefrontCountryCode: {
                    "RUS"
                },
            ),
        )
        root.onInit()
        for _ in 0 ..< 1000 {
            if apple.observationCount == 1 {
                break
            }
            await Task.yield()
        }
        try await assertPending(
            root.purchase(
                plan: robokassa.plan,
            ),
        )
        await deliver(
            SubscriptionTransactionUpdate(
                transactionId: 2,
                planId: robokassa.plan.id,
                purchaseDate: Date(),
                isActive: true,
                isOwnerChanged: false,
            ),
            provider: apple,
            root: root,
        )
        try await assertPending(
            root.checkPurchase(),
        )
    }

    @Test(
        arguments: [SubscriptionSource.apple, .robokassa],
    )
    func retryingAPendingPurchaseUsesItsContextsContinuationRule(
        source: SubscriptionSource,
    ) async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: source,
        )
        let paymentID = UUID()
        provider.preparedPaymentID = paymentID
        provider.purchaseResult = .pending
        backend.payments[
            paymentID,
        ] = BillingPaymentResponse(
            id: paymentID,
            planId: provider.plan.id,
            status: .pending,
            confirmationUrl: nil,
            paymentMethodType: nil,
        )
        let root = makeRoot(
            backend: backend,
            provider: provider,
        )
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        try await assertPending(
            root.purchase(
                plan: provider.plan,
            ),
        )
        #expect(
            provider.purchaseCount == (source == .apple ? 2 : 1),
        )
        #expect(
            backend.checkedPayments.count == (source == .robokassa ? 1 : 0),
        )
    }

    private func makeRoot(
        backend: SubscriptionTestBackendRepository,
        provider: SubscriptionTestRepository,
    ) -> SubscriptionRootViewModel {
        SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: provider,
                robokassa: provider,
                getStorefrontCountryCode: {
                    "USA"
                },
            ),
        )
    }

    private func assertPending(
        _ outcome: SubscriptionPurchaseOutcome,
    ) {
        switch outcome {
        case .pending: break
        case .cancelled, .completed:
            Issue.record(
                "Old or unrelated access must not complete this purchase",
            )
        }
    }

    private func deliver(
        _ update: SubscriptionTransactionUpdate,
        provider: SubscriptionTestRepository,
        root: SubscriptionRootViewModel,
    ) async {
        let previousCount = provider.deliveredUpdateCount
        provider.observedUpdate = update
        provider.changes.send(
            .success(
                (),
            ),
        )
        for _ in 0 ..< 100 {
            if provider.deliveredUpdateCount > previousCount {
                break
            }
            await Task.yield()
        }
        #expect(
            provider.deliveredUpdateCount > previousCount,
        )
        await root.lastTask?.value
    }
}
