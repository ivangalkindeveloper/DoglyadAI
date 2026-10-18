@MainActor
final class SubscriptionRootActiveState: SubscriptionRootStateProtocol, @MainActor Equatable {
    let status: SubscriptionStatus

    init(
        status: SubscriptionStatus,
    ) {
        self.status = status
    }

    static func == (
        lhs: SubscriptionRootActiveState,
        rhs: SubscriptionRootActiveState,
    ) -> Bool {
        lhs.status == rhs.status
    }
}
