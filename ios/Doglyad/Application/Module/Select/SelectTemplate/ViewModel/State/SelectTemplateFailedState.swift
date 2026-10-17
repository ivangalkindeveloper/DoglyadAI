import Foundation

@MainActor
final class SelectTemplateFailedState: SelectTemplateStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
