import Foundation

@MainActor
final class StorageFailedState: StorageStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
