@MainActor
final class ReportReceivedSendingState: ReportReceivedStateProtocol, @MainActor Equatable {
    let report: USExaminationReport

    init(
        report: USExaminationReport,
    ) {
        self.report = report
    }

    static func == (
        lhs: ReportReceivedSendingState,
        rhs: ReportReceivedSendingState,
    ) -> Bool {
        lhs.report == rhs.report
    }
}
