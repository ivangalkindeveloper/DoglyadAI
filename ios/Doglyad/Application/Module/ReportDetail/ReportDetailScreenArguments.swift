import Router

final class ReportDetailScreenArguments: RouteArgumentsProtocol {
    let report: USExaminationReport

    init(
        report: USExaminationReport
    ) {
        self.report = report
    }
}
