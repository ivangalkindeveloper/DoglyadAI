@MainActor
final class SubscriptionRootActiveState: SubscriptionRootStateProtocol {
    let status: SubscriptionStatus

    init(
        status: SubscriptionStatus,
    ) {
        self.status = status
    }
}
