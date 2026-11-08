import Foundation

@MainActor
final class ShareLoadingState: ShareStateProtocol, @MainActor Equatable {
    static func == (
        _: ShareLoadingState,
        _: ShareLoadingState,
    ) -> Bool {
        true
    }
}
