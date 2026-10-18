import Foundation

@MainActor
final class SubscriptionPaywallLoadingState: SubscriptionPaywallStateProtocol, @MainActor Equatable {
    static func == (
        _: SubscriptionPaywallLoadingState,
        _: SubscriptionPaywallLoadingState,
    ) -> Bool {
        true
    }
}
