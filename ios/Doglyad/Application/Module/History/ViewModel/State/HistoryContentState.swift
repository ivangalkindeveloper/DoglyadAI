@MainActor
final class HistoryContentState: HistoryStateProtocol, @MainActor Equatable {
    static func == (
        _: HistoryContentState,
        _: HistoryContentState,
    ) -> Bool {
        true
    }
}
