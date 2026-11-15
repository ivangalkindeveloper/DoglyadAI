@MainActor
final class ReportReceivedLoadingState: ReportReceivedStateProtocol, @MainActor Equatable {
    let report: USExaminationReport

    init(
        report: USExaminationReport,
    ) {
        self.report = report
    }

    func copyWith(
        report: USExaminationReport? = nil,
    ) -> ReportReceivedLoadingState {
        ReportReceivedLoadingState(
            report: report ?? self.report,
        )
    }

    static func == (
        lhs: ReportReceivedLoadingState,
        rhs: ReportReceivedLoadingState,
    ) -> Bool {
        lhs.report == rhs.report
    }
}
