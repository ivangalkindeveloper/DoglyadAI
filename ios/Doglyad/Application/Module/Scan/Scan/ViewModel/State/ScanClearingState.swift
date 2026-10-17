import Foundation

@MainActor
final class ScanClearingState: ScanStateProtocol {
    let previousState: any ScanStateProtocol

    init(
        previousState: any ScanStateProtocol,
    ) {
        self.previousState = previousState
    }
}
