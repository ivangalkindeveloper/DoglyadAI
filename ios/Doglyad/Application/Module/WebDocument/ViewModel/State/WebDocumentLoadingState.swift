import Foundation

@MainActor
final class WebDocumentLoadingState: WebDocumentStateProtocol, @MainActor Equatable {
    static func == (
        _: WebDocumentLoadingState,
        _: WebDocumentLoadingState,
    ) -> Bool {
        true
    }
}
