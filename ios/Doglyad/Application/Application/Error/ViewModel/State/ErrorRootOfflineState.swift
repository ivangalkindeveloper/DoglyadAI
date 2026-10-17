import Foundation

@MainActor
final class ErrorRootOfflineState: ErrorRootStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
