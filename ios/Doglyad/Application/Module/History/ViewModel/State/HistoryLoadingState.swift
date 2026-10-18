@MainActor
final class HistoryLoadingState: HistoryStateProtocol, @MainActor Equatable {
    static func == (
        _: HistoryLoadingState,
        _: HistoryLoadingState,
    ) -> Bool {
        true
    }
}
