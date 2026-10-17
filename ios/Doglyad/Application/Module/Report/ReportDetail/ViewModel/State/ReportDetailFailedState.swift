import Foundation

@MainActor
final class ReportDetailFailedState: ReportDetailStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
