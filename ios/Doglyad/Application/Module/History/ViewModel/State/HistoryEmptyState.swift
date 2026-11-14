@MainActor
final class HistoryEmptyState: HistoryStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: HistoryEmptyState,
        _: HistoryEmptyState,
    ) -> Bool {
        true
    }
}
