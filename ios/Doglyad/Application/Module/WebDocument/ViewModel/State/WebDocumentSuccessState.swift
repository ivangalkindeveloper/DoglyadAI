import Foundation

@MainActor
final class WebDocumentSuccessState: WebDocumentStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: WebDocumentSuccessState,
        _: WebDocumentSuccessState,
    ) -> Bool {
        true
    }
}
