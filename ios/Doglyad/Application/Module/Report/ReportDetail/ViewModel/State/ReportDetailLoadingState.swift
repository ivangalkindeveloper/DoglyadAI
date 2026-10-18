import Foundation

@MainActor
final class ReportDetailLoadingState: ReportDetailStateProtocol, @MainActor Equatable {
    let candidate: USExaminationReport

    init(
        candidate: USExaminationReport,
    ) {
        self.candidate = candidate
    }

    static func == (
        lhs: ReportDetailLoadingState,
        rhs: ReportDetailLoadingState,
    ) -> Bool {
        lhs.candidate == rhs.candidate
    }
}
