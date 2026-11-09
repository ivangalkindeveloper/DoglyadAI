import Foundation

@MainActor
final class ReportDetailErrorState: ReportDetailStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ReportDetailErrorState,
        rhs: ReportDetailErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
