import Foundation

@MainActor
final class ReportDetailLoadingState: ReportDetailStateProtocol {
    let candidate: USExaminationReport

    init(
        candidate: USExaminationReport,
    ) {
        self.candidate = candidate
    }
}
