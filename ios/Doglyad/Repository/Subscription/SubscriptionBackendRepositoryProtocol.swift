import Foundation

@MainActor
protocol SubscriptionBackendRepositoryProtocol: AnyObject {
    func configureIdentity() async throws

    func fetchOwnerID() async throws -> UUID

    func fetchPlans() async throws -> BillingProductsResponse

    func fetchStatus(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus?

    func synchronizeAppleTransaction(
        signedTransaction: String,
    ) async throws -> Bool

    func setAutoRenewal(
        isAutoRenewing: Bool,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus?

    func fetchRecoveryKey() async throws -> String

    func recover(
        key: String,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus?

    func preparePayment(
        planID: String,
        price: BillingPrice,
        isAutoRenewing: Bool,
    ) async throws -> BillingPreparePaymentResponse

    func checkPayment(
        id: UUID,
        isAbandoned: Bool,
    ) async throws -> BillingPaymentResponse
}
