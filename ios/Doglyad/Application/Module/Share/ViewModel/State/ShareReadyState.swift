import Foundation

@MainActor
final class ShareReadyState: ShareStateProtocol, @MainActor Equatable {
    static func == (
        _: ShareReadyState,
        _: ShareReadyState,
    ) -> Bool {
        true
    }
}
