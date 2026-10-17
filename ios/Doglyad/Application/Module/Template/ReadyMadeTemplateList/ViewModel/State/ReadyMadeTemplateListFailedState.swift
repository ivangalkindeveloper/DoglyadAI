import Foundation

@MainActor
final class ReadyMadeTemplateListFailedState: ReadyMadeTemplateListStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
