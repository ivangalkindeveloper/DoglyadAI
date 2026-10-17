import Foundation

@MainActor
final class ErrorRootUnknownState: ErrorRootStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
