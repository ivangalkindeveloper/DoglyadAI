import Foundation

@MainActor
final class ScanClearingState: ScanStateProtocol, @MainActor Equatable {
    let previousState: any ScanStateProtocol

    init(
        previousState: any ScanStateProtocol,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: ScanClearingState,
        rhs: ScanClearingState,
    ) -> Bool {
        (lhs.previousState as? any Equatable)?.isEqual(
            to: rhs.previousState,
        ) == true
    }
}
