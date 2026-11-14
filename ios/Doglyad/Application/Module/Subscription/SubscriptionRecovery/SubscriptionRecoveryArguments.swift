import Router

final class SubscriptionRecoveryArguments: RouteArgumentsProtocol {
    let onRecovered: (() -> Void)?

    init(
        onRecovered: (() -> Void)? = nil,
    ) {
        self.onRecovered = onRecovered
    }
}
