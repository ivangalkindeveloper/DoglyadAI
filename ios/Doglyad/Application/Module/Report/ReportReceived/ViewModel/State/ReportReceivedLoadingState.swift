@MainActor
final class ReportReceivedLoadingState: ReportReceivedStateProtocol, @MainActor Equatable {
    let report: USExaminationReport

    init(
        report: USExaminationReport,
    ) {
        self.report = report
    }

    static func == (
        lhs: ReportReceivedLoadingState,
        rhs: ReportReceivedLoadingState,
    ) -> Bool {
        lhs.report == rhs.report
    }
}
