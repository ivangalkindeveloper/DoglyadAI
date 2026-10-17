import Foundation

@MainActor
final class SubscriptionActiveState: SubscriptionStateProtocol {
    let status: SubscriptionStatus

    init(
        status: SubscriptionStatus,
    ) {
        self.status = status
    }
}
