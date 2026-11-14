@MainActor
final class SubscriptionManageCatalogLoadingState: SubscriptionManageLoadingState {
    required init(
        previousState: SubscriptionManageSuccessState? = nil,
    ) {
        super.init(
            previousState: previousState,
        )
    }
}
