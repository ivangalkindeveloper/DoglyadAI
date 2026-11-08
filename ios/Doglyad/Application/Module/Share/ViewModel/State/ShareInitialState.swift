import Foundation

@MainActor
final class ShareInitialState: ShareStateProtocol, @MainActor Equatable {
    static func == (
        _: ShareInitialState,
        _: ShareInitialState,
    ) -> Bool {
        true
    }
}
