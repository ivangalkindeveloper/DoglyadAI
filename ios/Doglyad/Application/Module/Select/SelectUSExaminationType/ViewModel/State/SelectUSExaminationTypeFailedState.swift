import Foundation

@MainActor
final class SelectUSExaminationTypeFailedState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: SelectUSExaminationTypeFailedState,
        rhs: SelectUSExaminationTypeFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
