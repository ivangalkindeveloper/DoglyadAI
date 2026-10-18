@MainActor
final class ReportReceivedDefaultState: ReportReceivedStateProtocol, @MainActor Equatable {
    static func == (
        _: ReportReceivedDefaultState,
        _: ReportReceivedDefaultState,
    ) -> Bool {
        true
    }
}
