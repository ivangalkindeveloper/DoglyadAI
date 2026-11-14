import Router

final class SubscriptionAutoRenewalDisablingArguments: RouteArgumentsProtocol {
    let onDisableSuccess: (() -> Void)?

    init(
        onDisableSuccess: (() -> Void)? = nil,
    ) {
        self.onDisableSuccess = onDisableSuccess
    }
}
