import Foundation

@MainActor
final class ReportReceivedDeliveryFailedState: ReportReceivedStateProtocol, @MainActor Equatable {
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
        lhs: ReportReceivedDeliveryFailedState,
        rhs: ReportReceivedDeliveryFailedState,
    ) -> Bool {
        lhs === rhs || lhs.report == rhs.report && lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
