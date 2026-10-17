import Foundation

@MainActor
final class SelectUSExaminationTypeFailedState: SelectUSExaminationTypeStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
