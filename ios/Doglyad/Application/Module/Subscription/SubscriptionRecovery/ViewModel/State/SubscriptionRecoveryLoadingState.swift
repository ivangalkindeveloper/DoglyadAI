@MainActor
class SubscriptionRecoveryLoadingState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    let previousState: any SubscriptionRecoveryStateProtocol

    init(
        previousState: any SubscriptionRecoveryStateProtocol,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: SubscriptionRecoveryLoadingState,
        rhs: SubscriptionRecoveryLoadingState,
    ) -> Bool {
        guard type(
            of: lhs,
        ) == type(
            of: rhs,
        ), let previous = lhs.previousState as? any Equatable else {
            return false
        }
        return previous.isEqual(
            to: rhs.previousState,
        )
    }
}
