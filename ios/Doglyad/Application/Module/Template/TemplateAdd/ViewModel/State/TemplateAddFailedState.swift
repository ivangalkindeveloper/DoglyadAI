import Foundation

@MainActor
final class TemplateAddFailedState: TemplateAddStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
