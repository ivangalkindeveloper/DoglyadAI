import Foundation

@MainActor
final class SubscriptionCustomerCenterLoadingState: SubscriptionCustomerCenterStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionCustomerCenterLoadingState,
        _: SubscriptionCustomerCenterLoadingState,
    ) -> Bool {
        true
    }
}
