import Foundation

@MainActor
final class ShareInitialState: ShareStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ShareInitialState,
        _: ShareInitialState,
    ) -> Bool {
        true
    }
}
