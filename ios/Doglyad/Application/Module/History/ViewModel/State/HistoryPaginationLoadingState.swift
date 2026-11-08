@MainActor
final class HistoryPaginationLoadingState: HistoryStateProtocol, @MainActor Equatable {
    static func == (
        _: HistoryPaginationLoadingState,
        _: HistoryPaginationLoadingState,
    ) -> Bool {
        true
    }
}
