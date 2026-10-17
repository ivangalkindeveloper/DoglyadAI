import Foundation

@MainActor
final class ShareFailedState: ShareStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
