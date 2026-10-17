import Foundation

@MainActor
final class SubscriptionPaywallFailedState: SubscriptionPaywallStateProtocol {
    let errorDescription: String

    init(
        errorDescription: String,
    ) {
        self.errorDescription = errorDescription
    }
}
