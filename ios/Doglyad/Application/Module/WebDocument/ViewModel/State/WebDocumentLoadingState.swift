import Foundation

@MainActor
final class WebDocumentLoadingState: WebDocumentStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: WebDocumentLoadingState,
        _: WebDocumentLoadingState,
    ) -> Bool {
        true
    }
}
