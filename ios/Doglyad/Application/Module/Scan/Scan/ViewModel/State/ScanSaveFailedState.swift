import Foundation

@MainActor
final class ScanSaveFailedState: ScanStateProtocol, @MainActor Equatable {
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

    static func == (
        lhs: ScanSaveFailedState,
        rhs: ScanSaveFailedState,
    ) -> Bool {
        lhs === rhs || lhs.snapshot == rhs.snapshot
            && lhs.report == rhs.report
            && lhs.error.isEqual(
                to: rhs.error,
            )
    }
}
