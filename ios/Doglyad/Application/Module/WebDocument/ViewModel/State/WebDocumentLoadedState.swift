import Foundation

@MainActor
final class WebDocumentLoadedState: WebDocumentStateProtocol, @MainActor Equatable {
    static func == (
        _: WebDocumentLoadedState,
        _: WebDocumentLoadedState,
    ) -> Bool {
        true
    }
}
