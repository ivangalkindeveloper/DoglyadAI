@MainActor
final class ManageSubscriptionFailedState: ManageSubscriptionStateProtocol, @MainActor Equatable {
    let previousState: ManageSubscriptionSuccessState?
    let errorDescription: String

    init(
        previousState: ManageSubscriptionSuccessState? = nil,
        errorDescription: String,
    ) {
        self.previousState = previousState
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: ManageSubscriptionFailedState,
        rhs: ManageSubscriptionFailedState,
    ) -> Bool {
        lhs.previousState == rhs.previousState && lhs.errorDescription == rhs.errorDescription
    }
}
