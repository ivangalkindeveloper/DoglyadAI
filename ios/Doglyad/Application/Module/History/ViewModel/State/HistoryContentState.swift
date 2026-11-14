@MainActor
final class HistoryContentState: HistoryStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: HistoryContentState,
        _: HistoryContentState,
    ) -> Bool {
        true
    }
}
