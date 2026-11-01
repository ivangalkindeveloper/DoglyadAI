@MainActor
final class ManageSubscriptionLoadingState: ManageSubscriptionStateProtocol, @MainActor Equatable {
    let previousState: ManageSubscriptionContentState?

    init(
        previousState: ManageSubscriptionContentState? = nil,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: ManageSubscriptionLoadingState,
        rhs: ManageSubscriptionLoadingState,
    ) -> Bool {
        lhs.previousState == rhs.previousState
    }
}
