@MainActor
final class SubscriptionManageRefundLoadingState: SubscriptionManageLoadingState {
    required init(
        previousState: SubscriptionManageSuccessState? = nil,
    ) {
        super.init(
            previousState: previousState,
        )
    }
}
