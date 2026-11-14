@MainActor
final class SubscriptionManageErrorState: SubscriptionManageStateProtocol, @MainActor Equatable {
    let previousState: SubscriptionManageSuccessState?
    let errorDescription: String

    init(
        previousState: SubscriptionManageSuccessState? = nil,
        errorDescription: String,
    ) {
        self.previousState = previousState
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: SubscriptionManageErrorState,
        rhs: SubscriptionManageErrorState,
    ) -> Bool {
        lhs.previousState == rhs.previousState && lhs.errorDescription == rhs.errorDescription
    }
}
