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

    func cancelRenewal() async throws

    func createRecoveryKey() async throws -> String

    func recover(
        key: String,
    ) async throws

    func preparePayment(
        planID: String,
    ) async throws -> BillingPreparePaymentResponse

    func tokenizePayment(
        request: BillingTokenizePaymentRequest,
    ) async throws -> BillingPaymentResponse

    func checkPayment(
        id: UUID,
        isAbandoned: Bool,
    ) async throws -> BillingPaymentResponse
}
