import Combine
@testable import Doglyad
import Foundation

@MainActor
final class SubscriptionTestRepository: SubscriptionRepositoryProtocol {
    let changes = PassthroughSubject<Result<Void, Error>, Never>()
    let backend: SubscriptionTestBackendRepository
    let plan: SubscriptionPlan
    var purchaseResult = PaywallTests.PurchaseResult.cancelled
    var observationCount = 0
    var purchaseCount = 0
    var restoreCount = 0
    var manageCount = 0
    var refundCount = 0
    var tiers = [
        SubscriptionTier(
            id: .base,
            title: "Server Base",
            features: ["Base model"],
        ),
        SubscriptionTier(
            id: .pro,
            title: "Server Pro",
            features: ["Pro model", "Voice", "Email"],
        ),
    ]
    var onFetchCatalog: (() async throws -> Void)?
    var onRestore: (() async throws -> Void)?
    var availablePlans: [SubscriptionPlan]?
    var purchasedPlan: SubscriptionPlan?
    var isLoadingFailed = false
    var isRestorableSubscriptionAvailable = true
    var onPurchase: (() async throws -> Void)?
    private(set) var purchasedIsAutoRenewing: Bool?
    var preparedPaymentID: UUID?
    var observedUpdate: SubscriptionTransactionUpdate?
    private(set) var deliveredUpdateCount = 0

    init(
        backend: SubscriptionTestBackendRepository? = nil,
        source: SubscriptionSource = .apple,
    ) {
        self.backend = backend ?? SubscriptionTestBackendRepository()
        plan = SubscriptionPlan(
            id: "monthly",
            source: source,
            type: .pro,
            period: .monthly,
            title: "Pro monthly",
            price: "$1.00",
        )
    }

    var status: SubscriptionStatus {
        get {
            backend.status
        }
        set {
            backend.status = newValue
        }
    }

    func observeChanges(
        _ observer: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
    ) async throws {
        let (stream, continuation) = AsyncStream<Result<Void, Error>>.makeStream()
        let observation = changes.sink {
            continuation.yield(
                $0,
            )
        }
        observationCount += 1
        defer {
            observation.cancel()
        }
        for await result in stream {
            try Task.checkCancellation()
            switch result {
            case .success:
                backend.isAccessAvailable = true
                observer(
                    .success(
                        observedUpdate ?? SubscriptionTransactionUpdate(
                            transactionId: 2,
                            planId: plan.id,
                            purchaseDate: Date(),
                            isActive: true,
                            isOwnerChanged: false,
                        ),
                    ),
                )
            case let .failure(
                error,
            ):
                observer(
                    .failure(
                        error,
                    ),
                )
            }
            deliveredUpdateCount += 1
        }
    }

    func fetchCatalog() async throws -> SubscriptionCatalog {
        try await onFetchCatalog?()
        if isLoadingFailed {
            throw SubscriptionError.offeringsUnavailable
        }
        return SubscriptionCatalog(
            tiers: tiers,
            plans: availablePlans ?? [plan],
        )
    }

    func purchase(
        plan: SubscriptionPlan,
        isAutoRenewing: Bool,
        onPurchasePrepared: @escaping (SubscriptionPurchaseContextProtocol) -> Void,
    ) async throws -> SubscriptionPurchaseOutcome {
        guard plan.source == self.plan.source else {
            throw SubscriptionError.offeringsUnavailable
        }
        purchaseCount += 1
        purchasedPlan = plan
        purchasedIsAutoRenewing = isAutoRenewing
        try await onPurchase?()
        switch plan.source {
        case .apple:
            onPurchasePrepared(
                SubscriptionStoreKitPurchaseContext(
                    planID: plan.id,
                    previousTransactionID: 1,
                    previousPurchaseDate: .distantPast,
                ),
            )
        case .robokassa:
            onPurchasePrepared(
                SubscriptionRobokassaPurchaseContext(
                    backend: backend,
                    paymentID: preparedPaymentID ?? UUID(),
                    planID: plan.id,
                ),
            )
        }
        switch purchaseResult {
        case .pending: return .pending
        case .cancelled: return .cancelled
        case .completed:
            backend.isAccessAvailable = true
            backend.status = SubscriptionStatus(
                planId: plan.id,
                type: plan.type,
                entitlement: backend.status.entitlement,
                availableCountPerDay: backend.status.availableCountPerDay,
                source: plan.source,
                expiresAt: backend.status.expiresAt,
                isAutoRenewing: backend.status.isAutoRenewing,
            )
            return .completed(
                nil,
            )
        case .failed: throw SubscriptionError.offeringsUnavailable
        }
    }

    func restorePurchases() async throws -> SubscriptionRestoreStrategy {
        restoreCount += 1
        try await onRestore?()
        guard plan.source == .apple else {
            return .recoveryKeyRequired
        }
        backend.isAccessAvailable = isRestorableSubscriptionAvailable
        return .completed(
            isOwnerChanged: false,
        )
    }

    func synchronizeCurrentEntitlements() async throws -> Bool {
        false
    }

    func manageSubscription() async throws {
        manageCount += 1
    }

    func requestRefund() async throws {
        refundCount += 1
    }
}
