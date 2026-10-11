import Router

final class ReportDetailArguments: RouteArgumentsProtocol {
    let report: USExaminationReport

    init(
        report: USExaminationReport,
    ) {
        self.report = report
    }
}
