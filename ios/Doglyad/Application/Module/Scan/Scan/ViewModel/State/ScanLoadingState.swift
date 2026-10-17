import Foundation

@MainActor
final class ScanLoadingState: ScanStateProtocol {
    let snapshot: USExaminationDraftForm
    let report: USExaminationReport

    init(
        report: USExaminationReport,
        snapshot: USExaminationDraftForm,
    ) {
        self.snapshot = snapshot
        self.report = report
    }
}
