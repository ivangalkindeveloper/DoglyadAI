import Foundation

@MainActor
final class SubscriptionActiveState: SubscriptionStateProtocol, @MainActor Equatable {
    let status: SubscriptionStatus

    init(
        status: SubscriptionStatus,
    ) {
        self.status = status
    }

    static func == (
        lhs: SubscriptionActiveState,
        rhs: SubscriptionActiveState,
    ) -> Bool {
        lhs.status == rhs.status
    }
}
