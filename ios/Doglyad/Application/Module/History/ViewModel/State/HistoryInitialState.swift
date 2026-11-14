@MainActor
final class HistoryInitialState: HistoryStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: HistoryInitialState,
        _: HistoryInitialState,
    ) -> Bool {
        true
    }
}
