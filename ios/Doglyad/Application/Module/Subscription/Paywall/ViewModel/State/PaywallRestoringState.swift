import Foundation

@MainActor
final class PaywallRestoringState: PaywallStateProtocol, @MainActor Equatable {
    let previousState: any PaywallStateProtocol

    init(
        previousState: any PaywallStateProtocol,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: PaywallRestoringState,
        rhs: PaywallRestoringState,
    ) -> Bool {
        (lhs.previousState as? any Equatable)?.isEqual(
            to: rhs.previousState,
        ) == true
    }
}
