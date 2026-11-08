@MainActor
class ManageSubscriptionLoadingState: ManageSubscriptionStateProtocol, @MainActor Equatable {
    let previousState: ManageSubscriptionSuccessState?

    required init(
        previousState: ManageSubscriptionSuccessState? = nil,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: ManageSubscriptionLoadingState,
        rhs: ManageSubscriptionLoadingState,
    ) -> Bool {
        type(
            of: lhs,
        ) == type(
            of: rhs,
        ) && lhs.previousState == rhs.previousState
    }
}
