import Foundation

@MainActor
final class ShareLoadingState: ShareStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ShareLoadingState,
        _: ShareLoadingState,
    ) -> Bool {
        true
    }
}
