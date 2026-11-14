@MainActor
final class SubscriptionManageRefreshLoadingState: SubscriptionManageLoadingState {
    required init(
        previousState: SubscriptionManageSuccessState? = nil,
    ) {
        super.init(
            previousState: previousState,
        )
    }
}
