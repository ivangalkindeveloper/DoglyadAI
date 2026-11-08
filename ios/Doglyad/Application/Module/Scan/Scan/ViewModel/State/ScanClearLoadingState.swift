import Foundation

@MainActor
final class ScanClearLoadingState: ScanStateProtocol, @MainActor Equatable {
    let previousState: any ScanStateProtocol

    init(
        previousState: any ScanStateProtocol,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: ScanClearLoadingState,
        rhs: ScanClearLoadingState,
    ) -> Bool {
        (lhs.previousState as? any Equatable)?.isEqual(
            to: rhs.previousState,
        ) == true
    }
}
