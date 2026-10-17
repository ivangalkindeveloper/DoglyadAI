import Foundation

@MainActor
final class ReportReceivedDeliveryFailedState: ReportReceivedStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
