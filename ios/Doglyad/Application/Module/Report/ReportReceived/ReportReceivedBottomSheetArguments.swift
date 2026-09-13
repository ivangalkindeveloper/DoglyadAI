import Router

final class ReportReceivedBottomSheetArguments: RouteArgumentsProtocol {
    let report: USExaminationReport

    init(
        report: USExaminationReport
    ) {
        self.report = report
    }
}
