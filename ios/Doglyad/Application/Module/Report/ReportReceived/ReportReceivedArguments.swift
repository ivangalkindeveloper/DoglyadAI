import Router

final class ReportReceivedArguments: RouteArgumentsProtocol {
    let report: USExaminationReport

    init(
        report: USExaminationReport,
    ) {
        self.report = report
    }
}
