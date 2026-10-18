import Foundation

@MainActor
final class ReportReceivedDeliveryFailedState: ReportReceivedStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ReportReceivedDeliveryFailedState,
        rhs: ReportReceivedDeliveryFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
