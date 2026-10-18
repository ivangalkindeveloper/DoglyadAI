import Foundation

@MainActor
final class ShareSendingState: ShareStateProtocol, @MainActor Equatable {
    static func == (
        _: ShareSendingState,
        _: ShareSendingState,
    ) -> Bool {
        true
    }
}
