import Foundation

@MainActor
final class SubscriptionRobokassaRepository: SubscriptionRepositoryProtocol {
    private let backend: SubscriptionBackendRepositoryProtocol
    private let openCheckout: (URL) async throws -> Bool

    init(
        backend: SubscriptionBackendRepositoryProtocol,
        openCheckout: @escaping (URL) async throws -> Bool = { url in
            try await RobokassaPaymentController().open(
                url: url,
            )
        },
    ) {
        self.backend = backend
        self.openCheckout = openCheckout
    }

    func fetchCatalog() async throws -> SubscriptionCatalog {
        let catalog = try await backend.fetchPlans()
        let plans = catalog.products.map { plan in
            SubscriptionPlan(
                id: plan.id,
                source: .robokassa,
                type: plan.entitlement,
                period: plan.period,
                title: plan.title,
                price: plan.formattedPrice(
                    plan.price.amountMinor.formattedCurrencyFromMinorUnits(
                        code: plan.price.currencyIso2Code,
                    ),
                ),
                billingPrice: plan.price,
            )
        }
        return SubscriptionCatalog(
            tiers: catalog.tiers,
            plans: plans,
        )
    }

    func purchase(
        plan: SubscriptionPlan,
        isAutoRenewing: Bool,
        onPurchasePrepared: @escaping (SubscriptionPurchaseContextProtocol) -> Void,
    ) async throws -> SubscriptionPurchaseOutcome {
        guard plan.source == .robokassa, let price = plan.billingPrice else {
            throw SubscriptionError.offeringsUnavailable
        }
        try Task.checkCancellation()
        let prepared = try await backend.preparePayment(
            planID: plan.id,
            price: price,
            isAutoRenewing: isAutoRenewing,
        )
        guard prepared.payment.planId == plan.id else {
            throw SubscriptionError.unverifiedTransaction
        }
        let context = SubscriptionRobokassaPurchaseContext(
            backend: backend,
            paymentID: prepared.payment.id,
            planID: plan.id,
        )
        onPurchasePrepared(
            context,
        )
        switch prepared.payment.status {
        case .succeeded:
            return .completed(
                nil,
            )
        case .canceled, .refunded:
            return .cancelled
        case .needsReview:
            return .pending
        case .created, .pending:
            break
        }
        guard let checkoutUrl = prepared.checkoutUrl, let url = URL(
            string: checkoutUrl,
        ),
            url.scheme == "https", url.host == "auth.robokassa.ru"
        else {
            throw SubscriptionError.unverifiedTransaction
        }
        try Task.checkCancellation()
        let isReturned = try await openCheckout(
            url,
        )
        return try await context.check(
            isAbandoned: !isReturned,
        )
    }

    func restorePurchases() async throws -> SubscriptionRestoreStrategy {
        .recoveryKeyRequired
    }

    func synchronizeCurrentEntitlements() async throws -> Bool {
        false
    }

    func observeChanges(
        _: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
    ) async throws {}

    func manageSubscription() async throws {
        throw SubscriptionError.offeringsUnavailable
    }

    func requestRefund() async throws {
        throw SubscriptionError.offeringsUnavailable
    }
}
