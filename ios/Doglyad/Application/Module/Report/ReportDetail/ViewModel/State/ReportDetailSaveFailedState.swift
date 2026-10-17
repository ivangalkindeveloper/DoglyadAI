import Foundation

@MainActor
final class ReportDetailSaveFailedState: ReportDetailStateProtocol {
    let candidate: USExaminationReport
    let error: Error

    init(
        candidate: USExaminationReport,
        error: Error,
    ) {
        self.candidate = candidate
        self.error = error
    }
}
