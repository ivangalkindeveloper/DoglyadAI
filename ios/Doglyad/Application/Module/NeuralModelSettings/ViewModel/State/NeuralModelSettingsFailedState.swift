import Foundation

@MainActor
final class NeuralModelSettingsFailedState: NeuralModelSettingsStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: NeuralModelSettingsFailedState,
        rhs: NeuralModelSettingsFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
