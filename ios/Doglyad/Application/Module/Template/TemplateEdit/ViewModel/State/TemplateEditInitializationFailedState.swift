import Foundation

@MainActor
final class TemplateEditInitializationFailedState: TemplateEditStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
