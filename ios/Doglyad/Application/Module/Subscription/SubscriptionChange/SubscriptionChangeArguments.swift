import Router

final class SubscriptionChangeArguments: RouteArgumentsProtocol {
    let source: SubscriptionSource?

    init(
        source: SubscriptionSource?,
    ) {
        self.source = source
    }
}
