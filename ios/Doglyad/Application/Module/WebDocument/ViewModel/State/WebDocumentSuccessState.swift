import Foundation

@MainActor
final class WebDocumentSuccessState: WebDocumentStateProtocol, @MainActor Equatable {
    static func == (
        _: WebDocumentSuccessState,
        _: WebDocumentSuccessState,
    ) -> Bool {
        true
    }
}
