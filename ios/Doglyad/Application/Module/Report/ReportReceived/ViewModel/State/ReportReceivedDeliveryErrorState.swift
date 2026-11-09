import Foundation

@MainActor
final class ReportReceivedDeliveryErrorState: ReportReceivedStateProtocol, @MainActor Equatable {
    let report: USExaminationReport
    let error: Error

    init(
        report: USExaminationReport,
        error: Error,
    ) {
        self.report = report
        self.error = error
    }

    static func == (
        lhs: ReportReceivedDeliveryErrorState,
        rhs: ReportReceivedDeliveryErrorState,
    ) -> Bool {
        lhs === rhs || lhs.report == rhs.report && lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
