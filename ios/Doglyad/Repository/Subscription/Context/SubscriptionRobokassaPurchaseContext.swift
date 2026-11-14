import Foundation

@MainActor
final class SubscriptionRobokassaPurchaseContext: SubscriptionPurchaseContextProtocol {
    private let backend: SubscriptionBackendRepositoryProtocol
    private let paymentID: UUID
    private let planID: String

    init(
        backend: SubscriptionBackendRepositoryProtocol,
        paymentID: UUID,
        planID: String,
    ) {
        self.backend = backend
        self.paymentID = paymentID
        self.planID = planID
    }

    func check() async throws -> SubscriptionPurchaseOutcome {
        try await check(
            isAbandoned: false,
        )
    }

    func check(
        transaction _: SubscriptionTransactionUpdate,
    ) -> SubscriptionPurchaseOutcome? {
        nil
    }

    func resume() async throws -> SubscriptionPurchaseOutcome? {
        try await check()
    }

    func check(
        isAbandoned: Bool,
    ) async throws -> SubscriptionPurchaseOutcome {
        let payment = try await backend.checkPayment(
            id: paymentID,
            isAbandoned: isAbandoned,
        )
        guard payment.id == paymentID, payment.planId == planID else {
            throw SubscriptionError.unverifiedTransaction
        }
        switch payment.status {
        case .succeeded:
            return .completed(
                nil,
            )
        case .canceled, .refunded: return .cancelled
        case .created, .pending, .needsReview: return .pending
        }
    }
}
