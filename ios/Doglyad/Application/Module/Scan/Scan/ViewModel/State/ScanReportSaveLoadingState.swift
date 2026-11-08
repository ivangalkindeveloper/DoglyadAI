import Foundation

@MainActor
final class ScanReportSaveLoadingState: ScanStateProtocol, @MainActor Equatable {
    let snapshot: USExaminationDraftForm
    let report: USExaminationReport

    init(
        report: USExaminationReport,
        snapshot: USExaminationDraftForm,
    ) {
        self.snapshot = snapshot
        self.report = report
    }

    static func == (
        lhs: ScanReportSaveLoadingState,
        rhs: ScanReportSaveLoadingState,
    ) -> Bool {
        lhs.snapshot == rhs.snapshot
            && lhs.report == rhs.report
    }
}
