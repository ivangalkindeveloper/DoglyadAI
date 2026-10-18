@MainActor
final class ReportReceivedSendingState: ReportReceivedStateProtocol, @MainActor Equatable {
    static func == (
        _: ReportReceivedSendingState,
        _: ReportReceivedSendingState,
    ) -> Bool {
        true
    }
}
