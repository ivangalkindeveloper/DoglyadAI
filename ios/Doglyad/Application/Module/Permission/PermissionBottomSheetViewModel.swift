@MainActor
final class PermissionBottomSheetViewModel: DViewModel {
    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        destination: AnalyticsBottomSheet
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(destination)
        )
    }
}
