@MainActor
class SubscriptionManageLoadingState: SubscriptionManageStateProtocol, @MainActor Equatable {
    let previousState: SubscriptionManageSuccessState?

    required init(
        previousState: SubscriptionManageSuccessState? = nil,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: SubscriptionManageLoadingState,
        rhs: SubscriptionManageLoadingState,
    ) -> Bool {
        type(
            of: lhs,
        ) == type(
            of: rhs,
        ) && lhs.previousState == rhs.previousState
    }
}
