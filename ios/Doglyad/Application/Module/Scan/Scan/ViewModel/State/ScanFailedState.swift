import Foundation

@MainActor
final class ScanFailedState: ScanStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
