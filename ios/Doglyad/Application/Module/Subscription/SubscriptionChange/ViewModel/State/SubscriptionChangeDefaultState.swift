@MainActor
final class SubscriptionChangeDefaultState: SubscriptionChangeStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SubscriptionChangeDefaultState,
        _: SubscriptionChangeDefaultState,
    ) -> Bool {
        true
    }
}
