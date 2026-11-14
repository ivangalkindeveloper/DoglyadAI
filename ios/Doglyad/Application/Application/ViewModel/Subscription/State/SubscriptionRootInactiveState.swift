@MainActor
final class SubscriptionRootInactiveState: SubscriptionRootStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SubscriptionRootInactiveState,
        _: SubscriptionRootInactiveState,
    ) -> Bool {
        true
    }
}
