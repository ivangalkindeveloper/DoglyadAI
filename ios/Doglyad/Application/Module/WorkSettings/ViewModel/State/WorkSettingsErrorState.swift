import Foundation

@MainActor
final class WorkSettingsErrorState: WorkSettingsStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: WorkSettingsErrorState,
        rhs: WorkSettingsErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
