import Foundation

@MainActor
final class SubscriptionPaywallRestoringState: SubscriptionPaywallStateProtocol {
    let previousState: any SubscriptionPaywallStateProtocol

    init(
        previousState: any SubscriptionPaywallStateProtocol,
    ) {
        self.previousState = previousState
    }
}
