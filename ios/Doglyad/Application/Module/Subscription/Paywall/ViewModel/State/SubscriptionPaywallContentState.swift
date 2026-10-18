import Foundation

@MainActor
final class SubscriptionPaywallContentState: SubscriptionPaywallStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionPaywallContentState,
        _: SubscriptionPaywallContentState,
    ) -> Bool {
        true
    }
}
