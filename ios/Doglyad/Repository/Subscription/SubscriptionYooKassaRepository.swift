import Foundation

@MainActor
final class SubscriptionYooKassaRepository: SubscriptionRepositoryProtocol {
    private let backend: SubscriptionBackendRepositoryProtocol

    init(
        backend: SubscriptionBackendRepositoryProtocol,
    ) {
        self.backend = backend
    }

    func fetchCatalog() async throws -> SubscriptionCatalog {
        let catalog = try await backend.fetchPlans()
        let plans = catalog.products.map { plan in
            SubscriptionPlan(
                id: plan.id,
                source: .yookassa,
                type: plan.entitlement,
                period: plan.period,
                title: plan.title,
                price: plan.formattedPrice(
                    plan.price.amountMinor.formattedCurrencyFromMinorUnits(
                        code: plan.price.currencyIso2Code,
                    ),
                ),
            )
        }
        return SubscriptionCatalog(
            tiers: catalog.tiers,
            plans: plans,
        )
    }

    func purchase(
        plan: SubscriptionPlan,
        onPurchasePrepared: @escaping (SubscriptionPurchaseReference) -> Void,
    ) async throws -> SubscriptionPurchaseOutcome {
        try Task.checkCancellation()
        let prepared = try await backend.preparePayment(
            planID: plan.id,
        )
        guard prepared.payment.planId == plan.id else {
            throw SubscriptionError.unverifiedTransaction
        }
        onPurchasePrepared(
            .yookassa(
                paymentId: prepared.payment.id,
            ),
        )
        // One SDK delegate per purchase prevents late callbacks from affecting a later purchase.
        let paymentController = YooKassaPaymentController()
        do {
            let outcome = try await completePayment(
                prepared,
                paymentController: paymentController,
            )
            await paymentController.close()
            return outcome
        } catch {
            await paymentController.close()
            throw error
        }
    }

    // YooKassa access is restored from backend status or an explicit recovery key.
    func restorePurchases() async throws -> Bool {
        false
    }

    // The backend receives YooKassa payments directly; there are no device entitlements to upload.
    func synchronizeCurrentEntitlements() async throws -> Bool {
        false
    }

    // YooKassa has no client transaction stream; the backend handles notifications and reconciliation.
    func observeChanges(
        _: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
    ) async throws {}

    func manageSubscription() async throws {
        try await backend.cancelRenewal()
    }

    // ManageSubscription routes YooKassa refund requests to merchant support.
    func requestRefund() async throws {
        throw SubscriptionError.offeringsUnavailable
    }

    private func completePayment(
        _ prepared: BillingPreparePaymentResponse,
        paymentController: YooKassaPaymentController,
    ) async throws -> SubscriptionPurchaseOutcome {
        var payment = try await refreshPaymentIfNeeded(
            prepared.payment,
        )
        switch payment.status {
        case .awaitingToken:
            guard let token = try await paymentController.tokenize(
                preparation: prepared,
            ) else {
                payment = try await backend.checkPayment(
                    id: payment.id,
                    isAbandoned: true,
                )
                return outcome(
                    payment.status,
                )
            }
            payment = try await backend.tokenizePayment(
                request: BillingTokenizePaymentRequest(
                    paymentId: payment.id,
                    paymentToken: token,
                    termsVersion: prepared.termsVersion,
                    isAutoRenewalAccepted: true,
                ),
            )
        case .created, .pending, .succeeded, .canceled, .refunded, .needsReview: break
        }
        try Task.checkCancellation()
        payment = try await confirmPaymentIfNeeded(
            payment,
            preparation: prepared,
            paymentController: paymentController,
        )
        return outcome(
            payment.status,
        )
    }

    private func refreshPaymentIfNeeded(
        _ payment: BillingPaymentResponse,
    ) async throws -> BillingPaymentResponse {
        switch payment.status {
        case .created, .pending:
            try await backend.checkPayment(
                id: payment.id,
                isAbandoned: false,
            )
        case .awaitingToken, .succeeded, .canceled, .refunded, .needsReview:
            payment
        }
    }

    private func confirmPaymentIfNeeded(
        _ payment: BillingPaymentResponse,
        preparation: BillingPreparePaymentResponse,
        paymentController: YooKassaPaymentController,
    ) async throws -> BillingPaymentResponse {
        switch payment.status {
        case .pending:
            try await paymentController.confirm(
                payment: payment,
                preparation: preparation,
            )
            return try await backend.checkPayment(
                id: payment.id,
                isAbandoned: false,
            )
        case .awaitingToken, .created, .succeeded, .canceled, .refunded, .needsReview:
            return payment
        }
    }

    private func outcome(
        _ state: BillingPaymentState,
    ) -> SubscriptionPurchaseOutcome {
        switch state {
        case .succeeded:
            .completed(
                nil,
            )
        case .canceled, .refunded: .cancelled
        case .awaitingToken, .created, .pending, .needsReview: .pending
        }
    }
}
