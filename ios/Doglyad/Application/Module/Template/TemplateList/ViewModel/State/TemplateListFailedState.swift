import Foundation

@MainActor
final class TemplateListFailedState: TemplateListStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
