@MainActor
final class SubscriptionRootInactiveState: SubscriptionRootStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionRootInactiveState,
        _: SubscriptionRootInactiveState,
    ) -> Bool {
        true
    }
}
