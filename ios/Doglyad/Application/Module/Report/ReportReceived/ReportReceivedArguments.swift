import Router

final class ReportReceivedArguments: RouteArgumentsProtocol {
    let isReportNavigationAvailable: Bool
    let report: USExaminationReport

    init(
        isReportNavigationAvailable: Bool = true,
        report: USExaminationReport,
    ) {
        self.isReportNavigationAvailable = isReportNavigationAvailable
        self.report = report
    }
}
