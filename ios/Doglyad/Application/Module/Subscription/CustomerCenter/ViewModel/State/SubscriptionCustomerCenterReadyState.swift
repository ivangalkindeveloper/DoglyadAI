import Foundation

@MainActor
final class SubscriptionCustomerCenterReadyState: SubscriptionCustomerCenterStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionCustomerCenterReadyState,
        _: SubscriptionCustomerCenterReadyState,
    ) -> Bool {
        true
    }
}
