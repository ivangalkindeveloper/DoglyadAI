@MainActor
final class SubscriptionInactiveState: SubscriptionStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionInactiveState,
        _: SubscriptionInactiveState,
    ) -> Bool {
        true
    }
}
