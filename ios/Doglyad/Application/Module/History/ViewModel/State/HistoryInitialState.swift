@MainActor
final class HistoryInitialState: HistoryStateProtocol, @MainActor Equatable {
    static func == (
        _: HistoryInitialState,
        _: HistoryInitialState,
    ) -> Bool {
        true
    }
}
