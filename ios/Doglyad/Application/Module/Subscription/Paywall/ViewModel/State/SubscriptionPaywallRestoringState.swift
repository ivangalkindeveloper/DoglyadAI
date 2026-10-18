import Foundation

@MainActor
final class SubscriptionPaywallRestoringState: SubscriptionPaywallStateProtocol, @MainActor Equatable {
    let previousState: any SubscriptionPaywallStateProtocol

    init(
        previousState: any SubscriptionPaywallStateProtocol,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: SubscriptionPaywallRestoringState,
        rhs: SubscriptionPaywallRestoringState,
    ) -> Bool {
        (lhs.previousState as? any Equatable)?.isEqual(
            to: rhs.previousState,
        ) == true
    }
}
