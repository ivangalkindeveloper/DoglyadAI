@MainActor
final class SubscriptionRecoveryKeyState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    let key: String

    init(
        key: String,
    ) {
        self.key = key
    }

    static func == (
        lhs: SubscriptionRecoveryKeyState,
        rhs: SubscriptionRecoveryKeyState,
    ) -> Bool {
        lhs.key == rhs.key
    }
}
