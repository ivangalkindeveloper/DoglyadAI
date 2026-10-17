import Foundation

@MainActor
final class TemplateEditFailedState: TemplateEditStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
