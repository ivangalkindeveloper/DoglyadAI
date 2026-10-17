import Foundation

@MainActor
final class ScanInitializationFailedState: ScanStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
