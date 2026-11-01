@MainActor
final class SubscriptionRecoveryDefaultState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionRecoveryDefaultState,
        _: SubscriptionRecoveryDefaultState,
    ) -> Bool {
        true
    }
}
