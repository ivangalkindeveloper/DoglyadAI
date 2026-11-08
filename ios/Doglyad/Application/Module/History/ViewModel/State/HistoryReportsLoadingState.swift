@MainActor
final class HistoryReportsLoadingState: HistoryStateProtocol, @MainActor Equatable {
    static func == (
        _: HistoryReportsLoadingState,
        _: HistoryReportsLoadingState,
    ) -> Bool {
        true
    }
}
