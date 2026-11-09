@MainActor
final class ManageSubscriptionErrorState: ManageSubscriptionStateProtocol, @MainActor Equatable {
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
        lhs: ManageSubscriptionErrorState,
        rhs: ManageSubscriptionErrorState,
    ) -> Bool {
        lhs.previousState == rhs.previousState && lhs.errorDescription == rhs.errorDescription
    }
}
