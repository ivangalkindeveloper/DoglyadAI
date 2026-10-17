import Foundation

@MainActor
final class WebDocumentFailedState: WebDocumentStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
