@MainActor
final class SubscriptionAutoRenewalDisablingLoadingState: SubscriptionAutoRenewalDisablingStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SubscriptionAutoRenewalDisablingLoadingState,
        _: SubscriptionAutoRenewalDisablingLoadingState,
    ) -> Bool {
        true
    }
}
