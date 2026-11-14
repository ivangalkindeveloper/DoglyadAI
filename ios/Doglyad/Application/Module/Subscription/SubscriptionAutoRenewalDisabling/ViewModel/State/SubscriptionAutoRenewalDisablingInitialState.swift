@MainActor
final class SubscriptionAutoRenewalDisablingInitialState: SubscriptionAutoRenewalDisablingStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SubscriptionAutoRenewalDisablingInitialState,
        _: SubscriptionAutoRenewalDisablingInitialState,
    ) -> Bool {
        true
    }
}
