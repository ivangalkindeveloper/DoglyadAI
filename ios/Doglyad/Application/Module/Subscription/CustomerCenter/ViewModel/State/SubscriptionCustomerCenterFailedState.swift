import Foundation

@MainActor
final class SubscriptionCustomerCenterFailedState: SubscriptionCustomerCenterStateProtocol {
    let errorDescription: String

    init(
        errorDescription: String,
    ) {
        self.errorDescription = errorDescription
    }
}
