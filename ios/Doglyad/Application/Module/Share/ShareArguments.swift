import Router

final class ShareArguments: RouteArgumentsProtocol {
    let report: USExaminationReport

    init(
        report: USExaminationReport
    ) {
        self.report = report
    }
}
