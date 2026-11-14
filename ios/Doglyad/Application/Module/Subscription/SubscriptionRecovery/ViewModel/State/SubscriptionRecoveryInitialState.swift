@MainActor
final class SubscriptionRecoveryInitialState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SubscriptionRecoveryInitialState,
        _: SubscriptionRecoveryInitialState,
    ) -> Bool {
        true
    }
}
