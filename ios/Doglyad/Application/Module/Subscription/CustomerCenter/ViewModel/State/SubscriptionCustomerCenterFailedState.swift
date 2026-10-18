import Foundation

@MainActor
final class SubscriptionCustomerCenterFailedState: SubscriptionCustomerCenterStateProtocol, @MainActor Equatable {
    let errorDescription: String

    init(
        errorDescription: String,
    ) {
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: SubscriptionCustomerCenterFailedState,
        rhs: SubscriptionCustomerCenterFailedState,
    ) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
