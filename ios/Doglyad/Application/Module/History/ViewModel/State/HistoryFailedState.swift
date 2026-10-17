import Foundation

@MainActor
final class HistoryFailedState: HistoryStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
