import Router

final class ReceivedReportBottomSheetArguments: RouteArgumentsProtocol {
    let report: USExaminationReport

    init(
        report: USExaminationReport
    ) {
        self.report = report
    }
}
