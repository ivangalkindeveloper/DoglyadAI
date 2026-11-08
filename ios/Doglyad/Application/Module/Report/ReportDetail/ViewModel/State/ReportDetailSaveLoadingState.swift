import Foundation

@MainActor
final class ReportDetailSaveLoadingState: ReportDetailStateProtocol, @MainActor Equatable {
    let candidate: USExaminationReport

    init(
        candidate: USExaminationReport,
    ) {
        self.candidate = candidate
    }

    static func == (
        lhs: ReportDetailSaveLoadingState,
        rhs: ReportDetailSaveLoadingState,
    ) -> Bool {
        lhs.candidate == rhs.candidate
    }
}
