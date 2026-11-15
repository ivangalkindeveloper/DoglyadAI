@MainActor
final class ReportReceivedContentState: ReportReceivedStateProtocol, @MainActor Equatable {
    let report: USExaminationReport

    init(
        report: USExaminationReport,
    ) {
        self.report = report
    }

    func copyWith(
        report: USExaminationReport? = nil,
    ) -> ReportReceivedContentState {
        ReportReceivedContentState(
            report: report ?? self.report,
        )
    }

    static func == (
        lhs: ReportReceivedContentState,
        rhs: ReportReceivedContentState,
    ) -> Bool {
        lhs.report == rhs.report
    }
}
