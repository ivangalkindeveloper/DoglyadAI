@MainActor
final class SubscriptionManageRestoreLoadingState: SubscriptionManageLoadingState {
    required init(
        previousState: SubscriptionManageSuccessState? = nil,
    ) {
        super.init(
            previousState: previousState,
        )
    }
}
