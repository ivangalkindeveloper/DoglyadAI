@MainActor
final class HistoryEmptyState: HistoryStateProtocol, @MainActor Equatable {
    static func == (
        _: HistoryEmptyState,
        _: HistoryEmptyState,
    ) -> Bool {
        true
    }
}
