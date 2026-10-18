import Foundation

@MainActor
final class SubscriptionPaywallFailedState: SubscriptionPaywallStateProtocol, @MainActor Equatable {
    let errorDescription: String

    init(
        errorDescription: String,
    ) {
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: SubscriptionPaywallFailedState,
        rhs: SubscriptionPaywallFailedState,
    ) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
