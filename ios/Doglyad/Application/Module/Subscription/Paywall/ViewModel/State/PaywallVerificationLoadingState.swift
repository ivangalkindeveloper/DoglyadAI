import Foundation

@MainActor
class PaywallVerificationLoadingState: PaywallStateProtocol, @MainActor Equatable {
    let previousState: any PaywallStateProtocol

    init(
        previousState: any PaywallStateProtocol,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: PaywallVerificationLoadingState,
        rhs: PaywallVerificationLoadingState,
    ) -> Bool {
        type(
            of: lhs,
        ) == type(
            of: rhs,
        ) && (lhs.previousState as? any Equatable)?.isEqual(
            to: rhs.previousState,
        ) == true
    }
}
