@MainActor
final class SubscriptionRecoveryInitialState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionRecoveryInitialState,
        _: SubscriptionRecoveryInitialState,
    ) -> Bool {
        true
    }
}
