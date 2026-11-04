@MainActor
final class ReportReceivedDefaultState: ReportReceivedStateProtocol, @MainActor Equatable {
    let report: USExaminationReport

    init(
        report: USExaminationReport,
    ) {
        self.report = report
    }

    static func == (
        lhs: ReportReceivedDefaultState,
        rhs: ReportReceivedDefaultState,
    ) -> Bool {
        lhs.report == rhs.report
    }
}
