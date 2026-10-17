import Foundation

@MainActor
final class ScanSaveFailedState: ScanStateProtocol {
    let snapshot: USExaminationDraftForm
    let report: USExaminationReport
    let error: Error

    init(
        report: USExaminationReport,
        snapshot: USExaminationDraftForm,
        error: Error,
    ) {
        self.snapshot = snapshot
        self.report = report
        self.error = error
    }
}
