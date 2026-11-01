@testable import Doglyad
import Foundation
import Testing

@MainActor
struct SubscriptionPurchaseVerificationTests {
    @Test(
        arguments: [BillingPaymentState.pending, .needsReview, .created, .awaitingToken],
    )
    func existingAccessCannotCompleteUnconfirmedYooKassaPayment(
        paymentState: BillingPaymentState,
    ) async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .yookassa,
        )
        let id = UUID()
        provider.preparedPaymentID = id
        provider.purchaseResult = .pending
        backend.isAccessAvailable = true
        backend.status.source = .yookassa
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
        ): #expect(
                status?.planId == provider.plan.id,
            )
        case .cancelled, .pending: Issue.record(
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
            source: .yookassa,
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
        backend.status.source = .yookassa
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
        ) { try await root.checkPurchase() }
    }

    @Test
    func confirmedSelectedPaymentPreservesDifferentCurrentAccess() async throws {
        let backend = SubscriptionTestBackendRepository()
        let provider = SubscriptionTestRepository(
            backend: backend,
            source: .yookassa,
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
            source: .yookassa,
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
        ): #expect(
                status?.planId == "annual",
            )
        case .pending, .cancelled: Issue.record(
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
            if provider.observationCount == 1 { break }
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
        ): #expect(
                status?.planId == provider.plan.id,
            )
        case .pending, .cancelled: Issue.record(
                "A new verified transaction for the selected plan must complete",
            )
        }
    }

    private func makeRoot(
        backend: SubscriptionTestBackendRepository,
        provider: SubscriptionTestRepository,
    ) -> SubscriptionRootViewModel {
        SubscriptionRootViewModel(
            container: makeSubscriptionTestContainer(
                backend: backend,
                storeKit: provider,
                yooKassa: provider,
                getStorefrontCountryCode: { "USA" },
            ),
        )
    }

    private func assertPending(
        _ outcome: SubscriptionPurchaseOutcome,
    ) {
        switch outcome {
        case .pending: break
        case .cancelled, .completed: Issue.record(
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
            if provider.deliveredUpdateCount > previousCount { break }
            await Task.yield()
        }
        #expect(
            provider.deliveredUpdateCount > previousCount,
        )
        await root.lastTask?.value
    }
}
