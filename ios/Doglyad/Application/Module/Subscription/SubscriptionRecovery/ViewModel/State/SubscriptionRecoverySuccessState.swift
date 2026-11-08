@MainActor
final class SubscriptionRecoverySuccessState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    let key: String

    init(
        key: String,
    ) {
        self.key = key
    }

    static func == (
        lhs: SubscriptionRecoverySuccessState,
        rhs: SubscriptionRecoverySuccessState,
    ) -> Bool {
        lhs.key == rhs.key
    }
}
