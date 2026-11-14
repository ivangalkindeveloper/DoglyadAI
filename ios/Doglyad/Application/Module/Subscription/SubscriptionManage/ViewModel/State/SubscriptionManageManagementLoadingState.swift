@MainActor
final class SubscriptionManageManagementLoadingState: SubscriptionManageLoadingState {
    required init(
        previousState: SubscriptionManageSuccessState? = nil,
    ) {
        super.init(
            previousState: previousState,
        )
    }
}
