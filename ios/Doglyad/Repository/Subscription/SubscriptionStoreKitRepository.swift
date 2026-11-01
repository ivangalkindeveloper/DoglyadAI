import Foundation
import StoreKit
import UIKit

@MainActor
final class SubscriptionStoreKitRepository: SubscriptionRepositoryProtocol {
    private let backend: SubscriptionBackendRepositoryProtocol

    init(
        backend: SubscriptionBackendRepositoryProtocol,
    ) {
        self.backend = backend
    }

    func fetchCatalog() async throws -> SubscriptionCatalog {
        let catalog = try await backend.fetchPlans()
        let plans = catalog.products
        let products = try await Product.products(
            for: plans.map(
                \.id,
            ),
        )
        let offers = plans.compactMap { plan -> SubscriptionPlan? in
            guard let product = products.first(
                where: {
                    $0.id == plan.id
                },
            ),
                let storeKitPeriod = product.subscription?.subscriptionPeriod
            else {
                return nil
            }
            let period: SubscriptionPeriod? = switch storeKitPeriod.unit {
            case .day: nil
            case .week: storeKitPeriod.value == 1 ? .weekly : nil
            case .month:
                switch storeKitPeriod.value {
                case 1: .monthly
                case 6: .sixMonth
                default: nil
                }
            case .year: storeKitPeriod.value == 1 ? .annual : nil
            @unknown default: nil
            }
            guard let period else {
                return nil
            }
            guard period == plan.period else {
                return nil
            }
            return SubscriptionPlan(
                id: plan.id,
                source: .apple,
                type: plan.entitlement,
                period: period,
                title: plan.title,
                price: plan.formattedPrice(
                    product.displayPrice,
                ),
            )
        }
        return SubscriptionCatalog(
            tiers: catalog.tiers,
            plans: offers,
        )
    }

    func purchase(
        plan: SubscriptionPlan,
        onPurchasePrepared: @escaping (SubscriptionPurchaseReference) -> Void,
    ) async throws -> SubscriptionPurchaseOutcome {
        try Task.checkCancellation()
        let productID = plan.id
        guard let product = try await Product.products(
            for: [productID],
        ).first else {
            throw SubscriptionError.offeringsUnavailable
        }
        let ownerID = try await backend.fetchOwnerID()
        var previousTransactionId: UInt64?
        var previousPurchaseDate: Date?
        if let latest = await Transaction.latest(
            for: productID,
        ) {
            switch latest {
            case let .verified(
                transaction,
            ):
                previousTransactionId = transaction.id
                previousPurchaseDate = transaction.purchaseDate
            case .unverified: throw SubscriptionError.unverifiedTransaction
            }
        }
        try Task.checkCancellation()
        onPurchasePrepared(
            .apple(
                previousTransactionId: previousTransactionId,
                previousPurchaseDate: previousPurchaseDate,
            ),
        )
        switch try await product.purchase(
            options: [.appAccountToken(
                ownerID,
            )],
        ) {
        case let .success(
            verification,
        ):
            let update = try await synchronize(
                verification,
            )
            guard update.planId == productID, update.isActive else {
                throw SubscriptionError.unverifiedTransaction
            }
            return .completed(
                nil,
            )
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw SubscriptionError.unverifiedTransaction
        }
    }

    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        return try await synchronizeCurrentEntitlements()
    }

    func synchronizeCurrentEntitlements() async throws -> Bool {
        var isOwnerChanged = false
        for await result in Transaction.currentEntitlements {
            try Task.checkCancellation()
            let update = try await synchronize(
                result,
            )
            isOwnerChanged = isOwnerChanged || update.isOwnerChanged
        }
        for await result in Transaction.unfinished {
            try Task.checkCancellation()
            let update = try await synchronize(
                result,
            )
            isOwnerChanged = isOwnerChanged || update.isOwnerChanged
        }
        return isOwnerChanged
    }

    func observeChanges(
        _ observer: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
    ) async throws {
        for await result in Transaction.updates {
            try Task.checkCancellation()
            do {
                try await observer(
                    .success(
                        synchronize(
                            result,
                        ),
                    ),
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                observer(
                    .failure(
                        error,
                    ),
                )
            }
        }
    }

    func manageSubscription() async throws {
        try await AppStore.showManageSubscriptions(
            in: activeScene(),
        )
    }

    func requestRefund() async throws {
        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(
                transaction,
            ):
                _ = try await transaction.beginRefundRequest(
                    in: activeScene(),
                )
                return
            case .unverified: throw SubscriptionError.unverifiedTransaction
            }
        }
    }

    private func synchronize(
        _ result: VerificationResult<Transaction>,
    ) async throws -> SubscriptionTransactionUpdate {
        switch result {
        case let .verified(
            transaction,
        ):
            let isOwnerChanged = try await backend.synchronizeAppleTransaction(
                signedTransaction: result.jwsRepresentation,
            )
            await transaction.finish()
            return SubscriptionTransactionUpdate(
                transactionId: transaction.id,
                planId: transaction.productID,
                purchaseDate: transaction.purchaseDate,
                isActive: transaction.revocationDate == nil && !transaction.isUpgraded && (transaction.expirationDate.map {
                    $0 > Date()
                } ?? false),
                isOwnerChanged: isOwnerChanged,
            )
        case .unverified: throw SubscriptionError.unverifiedTransaction
        }
    }

    private func activeScene() throws -> UIWindowScene {
        guard let scene = UIApplication.shared.connectedScenes.compactMap(
            {
                $0 as? UIWindowScene
            },
        ).first(
            where: {
                switch $0.activationState {
                case .foregroundActive: true
                case .foregroundInactive, .background, .unattached: false
                @unknown default: false
                }
            },
        ) else {
            throw SubscriptionError.offeringsUnavailable
        }
        return scene
    }
}
