import Foundation

@MainActor
final class LegalUpdateFailedState: LegalUpdateStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
