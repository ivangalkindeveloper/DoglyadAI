import Foundation

@MainActor
final class ReportDetailFailedState: ReportDetailStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ReportDetailFailedState,
        rhs: ReportDetailFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
