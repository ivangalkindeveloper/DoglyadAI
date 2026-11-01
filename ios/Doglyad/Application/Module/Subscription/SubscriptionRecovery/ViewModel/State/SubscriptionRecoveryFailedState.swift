@MainActor
final class SubscriptionRecoveryFailedState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    let previousState: any SubscriptionRecoveryStateProtocol
    let errorDescription: String

    init(
        previousState: any SubscriptionRecoveryStateProtocol,
        errorDescription: String,
    ) {
        self.previousState = previousState
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: SubscriptionRecoveryFailedState,
        rhs: SubscriptionRecoveryFailedState,
    ) -> Bool {
        guard let previous = lhs.previousState as? any Equatable else {
            return false
        }
        return previous.isEqual(
            to: rhs.previousState,
        ) && lhs.errorDescription == rhs.errorDescription
    }
}
