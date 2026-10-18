import Foundation

@MainActor
final class ReportDetailSaveFailedState: ReportDetailStateProtocol, @MainActor Equatable {
    let candidate: USExaminationReport
    let error: Error

    init(
        candidate: USExaminationReport,
        error: Error,
    ) {
        self.candidate = candidate
        self.error = error
    }

    static func == (
        lhs: ReportDetailSaveFailedState,
        rhs: ReportDetailSaveFailedState,
    ) -> Bool {
        lhs === rhs || lhs.candidate == rhs.candidate
            && lhs.error.isEqual(
                to: rhs.error,
            )
    }
}
