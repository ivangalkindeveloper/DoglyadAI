@testable import Doglyad
import Foundation

@MainActor
final class SubscriptionTestBackendRepository: SubscriptionBackendRepositoryProtocol {
    var isAccessAvailable = false
    var status = SubscriptionStatus(
        planId: "monthly",
        type: .pro,
        entitlement: SubscriptionEntitlement(
            requestCountPerDay: 20,
            formCompletionViaMicrophone: .available,
            sendingReportByEmail: .available,
            settingsAI: .available,
        ),
        availableCountPerDay: 20,
        source: .apple,
    )
    var payments: [UUID: BillingPaymentResponse] = [:]
    private(set) var checkedPayments: [UUID] = []
    private(set) var isRenewalCanceled = false

    func configureIdentity() async throws {}

    func fetchOwnerID() async throws -> UUID { UUID() }

    func fetchPlans() async throws -> BillingProductsResponse {
        BillingProductsResponse(
            products: [],
            tiers: [],
        )
    }

    func fetchStatus(
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        isAccessAvailable ? status : nil
    }

    func synchronizeAppleTransaction(
        signedTransaction _: String,
    ) async throws -> Bool { false }

    func cancelRenewal() async throws { isRenewalCanceled = true }

    func createRecoveryKey() async throws -> String { "test-recovery-key" }

    func recover(
        key _: String,
    ) async throws { isAccessAvailable = true }

    func preparePayment(
        planID _: String,
    ) async throws -> BillingPreparePaymentResponse { throw SubscriptionError.offeringsUnavailable }

    func tokenizePayment(
        request _: BillingTokenizePaymentRequest,
    ) async throws -> BillingPaymentResponse { throw SubscriptionError.offeringsUnavailable }

    func checkPayment(
        id: UUID,
        isAbandoned _: Bool,
    ) async throws -> BillingPaymentResponse {
        checkedPayments.append(
            id,
        )
        guard let payment = payments[
            id,
        ] else { throw SubscriptionError.offeringsUnavailable }
        return payment
    }
}
